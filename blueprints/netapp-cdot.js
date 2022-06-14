// NetApp Clustered Data-OnTap pluggable blueprint for UpGuard
// Please contact UpGuard support for installation
// 2022-06-13 v1.1.1

// Changelog:
// v1.1.1 - updated ProgramOutputStdout to support larger incoming byte arrays

// Required permissions:
// Service user must be able to run the following commands:
//      version
//      timezone
//      system node run -node local -command sysconfig -a
//      system service-processor show -instance
//      security login show -instance
//      security login role show
//      df
//      storage disk show
//      dns show
//      network routing-groups route show
//      system node run -node local -command environment chassis all
//      system license show
//      options
//
// Additionally, service user must be able to modify output structure
// of commands that return output formatted into rows and columns. These
// commands are prefaced with:
//      set advanced; set -rows 0; set -showallfields true; set -showseparator "|||";

function main(targetHost) {
    class Serializer {
        constructor(__debug) {
            this.__debug = __debug;
            this.funcs = [];
            this.ret = [];
        }
    
        debug(msg) {
            if (this.__debug != null) {
                this.__debug(msg);
            }
        }
    
        add(fn) {
            this.funcs.push(fn);
            this.ret.push(null);
        }
    
        runi(i) {
            if (i >= this.funcs.length) {
                return this.ret;
            }
            this.debug("serializer, fn " + (i + 1) + " of " + this.funcs.length + "\n");
            return this.funcs[i]().then((reti) => { this.ret[i] = reti; return this.runi(i + 1); });
        }
    
        run() {
            // runs all input promises, returning a results array
            return this.runi(0);
        }
    }

    // convenience thing to get debug() function available
    let debug = targetHost.debug;

    // command boilerplate for easier parsing of tabular output
    let tabularOutputSetup = 'set advanced; set -rows 0; set -showallfields true; set -showseparator "|||"; '

    // this is an array of promises for all of the things we want to run
    let parts = [];

    // serialize tabular-output commands
    let serializer = new Serializer();

    // function to extract stdout from the runCmd response
    let programOutputStdout = resp => {
        let [exit_status, _stdout, _stderr] = resp;
        let stdout = '';
        for (var i=0; i < _stdout.byteLength; i++) {
            stdout += String.fromCharCode(_stdout[i]);
        }
        return stdout.trim();
    }

    function extractKeyValueObjects(text) {
        let entriesRegEx = /\d+ entr(y|ies) (was|were) displayed\./i;
        let objects = [];
        if (text.length === 0) {
            return objects;
        }
        let textLines = text.split("\r\n");
        let currentObject = {};
        for (line of textLines){
            // look for closing 'entries displayed' line
            if (entriesRegEx.test(line)) {
                break;
            }
            // look for blank lines between multiple entries
            if (line === '') {
                if (Object.keys(currentObject).length !== 0) {
                    objects.push(currentObject);
                }
                currentObject = {};
                continue;
            }
            let splitLine = line.trim().split(': ', 2);
            if (splitLine.length === 2) {
                currentObject[splitLine[0]] = splitLine[1];
            }
        }
        if (Object.keys(currentObject).length !== 0) {
            objects.push(currentObject);
        }
        return objects;
    }

    function extractTabularObjects(text, separator = '|||') {
        let objects = [];
        if (text === undefined || text.length === 0) {
            return objects;
        }
        let tabLines = text.split("\r\n");
        let shortNames = tabLines.shift().split(separator);
        let longNames = tabLines.shift().split(separator);

        for (line of tabLines){
            let currentObject = {}
            let splitLine = line.split(separator);

            for (let i = 0; i < splitLine.length; i++) {
                if (longNames[i] !== "") {
                    currentObject[longNames[i]] = splitLine[i];
                }
            }
            objects.push(currentObject);
        }

        return objects;
    }

    let basicTabularSection = (entries, sectionName, subSectionKey, ciKey) => {
        // entries - an array of objects, as from extractTabularObjects
        // sectionName - the name to use for the top level json object
        // subSectionKey - the object key to use for generating 2nd level json names
        // ciKey - the object key to use as the name of the CI

        let returnObj = {}

        for (entry of entries) {
            let subSectionName = entry[subSectionKey];
            let ciName = entry[ciKey];

            if (!(subSectionName in returnObj)) {
                returnObj[subSectionName] = {};
            }

            returnObj[subSectionName][ciName] = entry;
        }

        return { [sectionName]: returnObj };
    }

    //
    // run commands and put their output into the scan
    //

    // version
    parts.push(
      targetHost.runCmd("version").then(resp => {
          return { inventory: {
                        facts: {
                            version: {
                                value: programOutputStdout(resp)
                            }
                        }
                    }
                };
      })
    );

    // timezone
    parts.push(
      targetHost.runCmd("timezone").then(resp => {
          return { inventory: {
                        facts: {
                            timezone: {
                                value: programOutputStdout(resp).split(": ")[1]
                            }
                        }
                    }
                };
      })
    );

    // sysconfig -a (bespoke parsing)
    parts.push(
        targetHost.runCmd("system node run -node local -command sysconfig -a").then(resp => {
            let output = programOutputStdout(resp);
            let returnObj = {};

            // Stick the unprocessed command output in a file
            returnObj['files'] = {'netapp': { 'sysconfig': {'raw': output }}};

            let splitLines = output.split('\r\n');

            let sysconfigObject = {};
            let hardwareObjects = {};

            let isJunk = line => { return line === undefined || (line.includes("base 0x") && line.includes("size 0x")); };

            let isTopLevel = line => {
                // All top-level lines start with \t
                // Some second-level lines start with \t\t (some only use spaces)
                // Thanks Netapp
                if (line === undefined) { return false; }
                return line.startsWith('\t') && !line.startsWith('\t\t');
            }

            let splitOnce = (line, sep) => {
                // built-in javascript split() function does wrong thing
                let index = line.indexOf(sep);
                if (index == -1) { return [line]};
                return [line.slice(0, index).trim(), line.slice(index + 1).trim()];
            }

            // special handling for first line returned w/ no tab
            let firstLine = splitLines.shift();
            let left = splitOnce(firstLine, ':')[0]
            let right = splitOnce(firstLine, ':')[1]
            if (firstLine.includes('NetApp Release')) {
                sysconfigObject['NetApp Release'] = { 'value': left.split(' ', 3)[2], 
                                                      'time': right};
            } else {
                sysconfigObject[left] = { 'value': right };
            }

            let currentLine = splitLines.shift();
            while (currentLine !== undefined) {
                // discard lines with no config value, which always come at end of an object
                if (isJunk(currentLine)) {
                    currentLine = splitLines.shift();
                    continue;
                }
                if (isTopLevel(currentLine)) {
                    // Top level, either a key/value sysconfig attr or some kind of object.
                    if (currentLine.includes('[Service Processor cached network information determined')) {
                        // Noise line, discard
                        currentLine = splitLines.shift();
                        continue;
                    } else if (currentLine.startsWith('\tslot')) {
                        // hardware entry, create an object and process its attrs
                        let currentSplit = splitOnce(currentLine, ':');
                        let slotNum = currentSplit[0];
                        let deviceName = currentSplit[1];

                        if (!(slotNum in hardwareObjects)) {
                            hardwareObjects[slotNum] = {};
                        }

                        hardwareObjects[slotNum][deviceName] = {};

                        // process attrs for hardware object
                        while (true) {
                            currentLine = splitLines.shift()
                            if (isTopLevel(currentLine) || isJunk(currentLine)) {
                                // end of object reached, return to main loop to process currentLine
                                break;
                            } else if (currentLine.indexOf(':') === -1) {
                                // description line
                                hardwareObjects[slotNum][deviceName]['Description'] = currentLine.trim();
                            } else {
                                // normal case, key/val attr
                                let key = splitOnce(currentLine, ':')[0];

                                // peek ahead - does key have an array of values?
                                if (!isTopLevel(splitLines[0]) && !isJunk(splitLines[0]) && splitLines[0].indexOf(':') === -1) {
                                    // multi-value attr case, process lines until we hit junk or a different indent level
                                    let value = [splitOnce(currentLine, ':')[1]];
                                    while (true) {
                                        currentLine = splitLines.shift();
                                        if (!isTopLevel(currentLine) && !isJunk(currentLine) && currentLine.indexOf(':') === -1) {
                                            value.push(currentLine.trim());
                                        } else {
                                            hardwareObjects[slotNum][deviceName][key] = value;
                                            break;
                                        }
                                    }
                                } else {
                                    // no multi-value attr, normal case
                                    let value = splitOnce(currentLine, ':')[1];
                                    hardwareObjects[slotNum][deviceName][key] = value;
                                }
                            }
                        }
                    } else {
                        // Not a hardware object, either a sysconfig object or a sysconfig key/value
                        if (currentLine.includes('Status:')) {
                            // Sysconfig object with inline status, eg: `Service Processor           Status: Online`
                            let ciName = currentLine.split('Status:', 2)[0];
                            let statusValue= currentLine.split('Status:', 2)[1];

                            if (!(ciName in sysconfigObject)) {
                                sysconfigObject[ciName] = {};
                            }

                            sysconfigObject[ciName]['Status'] = statusValue;

                            while (true) {
                                // process other attrs
                                currentLine = splitLines.shift();
                                if (isTopLevel(currentLine) || isJunk(currentLine)) {
                                    break;
                                } else {
                                    let key = splitOnce(currentLine, ':')[0];
                                    let value = splitOnce(currentLine, ':')[1];
                                    sysconfigObject[ciName][key] = value;
                                }
                            }
                        } else if (currentLine.indexOf(':') !== -1 && splitOnce(currentLine, ':')[1] === '') {
                            // Sysconfig object with no inline status - eg: `IPv4 configuration:`
                            let ciName = splitOnce(currentLine, ':')[0]

                            if (!(ciName in sysconfigObject)) {
                                sysconfigObject[ciName] = {};
                            }

                            while (true) {
                                //process other attrs
                                currentLine = splitLines.shift();
                                if (isTopLevel(currentLine) || isJunk(currentLine)) {
                                    break;
                                } else {
                                    let key = splitOnce(currentLine, ':')[0];
                                    let value = splitOnce(currentLine, ':')[1];
                                    sysconfigObject[ciName][key] = value;
                                }
                            }
                        } else {
                            // Simple key-value, eg: `Backplane Part Number: 111-01459`
                            let ciName = splitOnce(currentLine, ':')[0]
                            let value = splitOnce(currentLine, ':')[1]

                            if (!(ciName in sysconfigObject)) {
                                sysconfigObject[ciName] = {};
                            }

                            sysconfigObject[ciName]['Value'] = value;
                            currentLine = splitLines.shift();
                        }
                    }
                } else {
                    // should never see this path, all deeper indents should be processed in their object blocks
                    // but let's keep it moving if we do get in here somehow
                    debug(currentLine.toString());
                    currentLine = splitLines.shift();
                }
            }

            returnObj['sysconfig'] = { 'netapp': sysconfigObject };
            returnObj['hardware'] = hardwareObjects;
            return returnObj;
        })
    );
    // system service-processor show (one key-value object)
    parts.push(
        targetHost.runCmd("system service-processor show -instance").then(resp => {
            let facts = extractKeyValueObjects(programOutputStdout(resp))[0];
            let returnObj = { inventory: { facts: {} } };

            for (key of Object.keys(facts)) {
                returnObj['inventory']['facts'][key] = { 'value': facts[key] };
            }

            return returnObj;
        })
    );

    // security login show (multiple key-value objects)
    parts.push(
        targetHost.runCmd("security login show -instance").then(resp => {
            let entries = extractKeyValueObjects(programOutputStdout(resp));
            let returnObj = {};

            for (entry of entries) {
                let sectionName = entry['Vserver'];
                if (!(sectionName in returnObj)) {
                    returnObj[sectionName] = {};
                }

                let ciNameKey = '';
                // Apparently can be multiple options for the key here.
                // User Name or Group Name || User Name or Active Directory Group Name
                if ('User Name or Group Name' in entry) {
                    ciNameKey = 'User Name or Group Name';
                } else {
                    ciNameKey = 'User Name or Active Directory Group Name';
                }
                let ciName = entry[ciNameKey] + '-' + entry['Application'];
                returnObj[sectionName][ciName] = entry;
            }

            return { 'logins': returnObj };
        })
    );


    // security login role show (tabular)
    serializer.add(() => {
        return targetHost.runCmd(tabularOutputSetup + "security login role show").then(resp => {
            let entries = extractTabularObjects(programOutputStdout(resp));
            let returnObj = {};

            for (entry of entries) {
                let sectionName = entry["Vserver"];
                let ciName = entry["Role Name"];

                if (!(sectionName in returnObj)) {
                    returnObj[sectionName] = {};
                }

                if (!(ciName in returnObj[sectionName])) {
                    returnObj[sectionName][ciName] = {};
                }

                let shortObj = {
                                 "Command / Directory": entry["Command / Directory"],
                                 "Query": entry["Query"],
                                 "Access Level": entry["Access Level"]
                               };
                returnObj[sectionName][ciName][entry["Command / Directory"]] = shortObj;
            }
            return { 'roles' : returnObj };
        })
    });

    // df (tabular)
    serializer.add(() => {
        return targetHost.runCmd(tabularOutputSetup + "df").then(resp => {
            let entries = extractTabularObjects(programOutputStdout(resp));
            let returnObj = {};

            for (entry of entries) {
                let subSectionName = entry["Vserver Name"];
                let ciName = entry["Volume Name"] + "-" + entry["Snapshot or Active File System"];

                if (!(subSectionName in returnObj)) {
                    returnObj[subSectionName] = {};
                }

                returnObj[subSectionName][ciName] = entry;
            }

            return { 'df' : returnObj };
        })
    });

    // storage disk show (tabular)
    serializer.add(() => {
        return targetHost.runCmd(tabularOutputSetup + "storage disk show").then(resp => {
            let entries = extractTabularObjects(programOutputStdout(resp));
            return basicTabularSection(entries, "disks", "Owner", "Disk Name");
        })
    });

    // dns show (tabular)
    serializer.add(() => {
        return targetHost.runCmd(tabularOutputSetup + "dns show").then(resp => {
            let entries = extractTabularObjects(programOutputStdout(resp));
            return basicTabularSection(entries, "dns", "Vserver", "Domains");
        })
    });

    // network routing-groups route show (tabular)
    serializer.add(() => {
        return targetHost.runCmd(tabularOutputSetup + "network routing-groups route show").then(resp => {
            let entries = extractTabularObjects(programOutputStdout(resp));
            return basicTabularSection(entries, "routes", "Vserver Name", "Routing Group");
        })
    });

    // environment chassis (tabular)
    // DOESN'T RESPOND TO TABULAR FORMATTING COMMANDS
    /* parts.push(
        targetHost.runCmd(tabularOutputSetup + "system node run -node local -command environment chassis all").then(resp => {
            let entries = extractTabularObjects(programOutputStdout(resp));
            let returnObj = {};

            for (entry of entries) {
                returnObj[entry['Sensor Name']] = entry;
            }

            return { 'chassis': {'Sensors': returnObj }};
        })
    ); */

    // license (tabular)
    serializer.add(() => {
        return targetHost.runCmd(tabularOutputSetup + "system license show").then(resp => {
            let output = programOutputStdout(resp);

            if (output.trim().includes('Error: show failed:')) {
                return { 'license': {'Netapp': { 'Error': { 'value': output.trim()}}}};
            }

            let returnObj = {};
            let entries = extractTabularObjects(output);
            return basicTabularSection(entries, 'license', 'Owner', 'Package');
        })
    });

    // options (tabular)
    serializer.add(() => {
        return targetHost.runCmd(tabularOutputSetup + "options").then(resp => {
            let entries = extractTabularObjects(programOutputStdout(resp));
            return basicTabularSection(entries, 'options', 'Vserver', 'Option Name');
        })
    });

    // trigger the serializer to run
    parts.push(serializer.run().then(partial_scans => {
        return targetHost.mergeAll(partial_scans);
    }));

    // once all of the constituent parts of
    // the blueprint have all returned
    return Promise.all(parts)
        // we merge all of the blueprint fragments
        //into one larger blueprint
        .then(partial_scans => {
            return targetHost.mergeAll(partial_scans);
        })
        // and then push the blueprint to the go agent
        .then(merged_scan => {
            targetHost.submitScan(merged_scan);
        });
}

// standard module export boilerplate
if (typeof module !== "undefined" && module.exports) {
    module.exports = main;
}