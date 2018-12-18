// Example 1 - ssh-exec-example.js
// A simple Linux pluggable blueprint, demonstrating
// the use of the runCmd method and SSH exec based configuration scanning.

function main(targetHost) {
    // Example function to extract exit code, stdout, and stderr from the runCmd response
    let programOutputCi = resp => {
        function decodeUtf8(data) {
            let ret = "";
            for (let i = 0; i < data.length; ) {
                let currentRune = 0;
                let currentRuneLen = 0;
                let valid = true;
                let b = data[i];
                if ((b & 0x80) === 0) {
                    currentRuneLen = 1;
                    currentRune = b & 0x7f;
                } else if ((b & 0xe0) === 0xc0) {
                    currentRuneLen = 2;
                    currentRune = b & 0x1f;
                } else if ((b & 0xf0) === 0xe0) {
                    currentRuneLen = 3;
                    currentRune = b & 0x0f;
                } else if ((b & 0xf8) === 0xf0) {
                    currentRuneLen = 4;
                    currentRune = b & 0x07;
                } else if ((b & 0xfc) === 0xf8) {
                    currentRuneLen = 5;
                    currentRune = b & 0x03;
                } else if ((b & 0xfe) === 0xfc) {
                    currentRuneLen = 6;
                    currentRune = b & 0x01;
                } else {
                    valid = false;
                }

                for (let j = 1; j < currentRuneLen && j + i < data.length; j++) {
                    let bn = data[i+j];
                    if ((bn & 0xc0) === 0x80) {
                        currentRune = (currentRune << 6) | (bn & 0x3f);
                    } else {
                        valid = false;
                    }
                }

                if (valid) {
                    i += currentRuneLen;
                    ret += String.fromCharCode(currentRune);
                } else {
                    i += 1;
                    ret += String.fromCharCode(b);
                }
            }
            return ret;
        }
        let [exit_status, _stdout, _stderr] = resp;
        let stdout = decodeUtf8(_stdout);
        let stderr = decodeUtf8(_stderr);
        return { exit_status: exit_status, stdout: stdout, stderr: stderr };
    };

    // **** BLUEPRINT STARTS HERE ****

    // this is an array of promises for all of the things we want to run
    let parts = [];

    // uname
    parts.push(
        targetHost.runCmd("uname -a").then(resp => {
            return { inventory: {
                          linux: {
                              // create a CI with three attributes:
                              // exit_status, stdout, and stderr
                              uname: programOutputCi(resp)
                          }
                      }
                  };
        })
    );
    // os-release
    parts.push(
        targetHost.runCmd("cat /etc/os-release").then(resp => {
            return { files: {
                          linux: {
                              "os-release": {
                                  // create a single raw file attribute
                                  // containing the decoded stdout stream
                                  raw: programOutputCi(resp)['stdout']
                              }
                          }
                      }
                  };
        })
    );

    // once all of the constituent parts of
    // the blueprint have returned
    return Promise.all(parts)
        .then(partial_scans => {
            // merge all of the returned scan fragments
            let merged_scans = targetHost.mergeAll(partial_scans);
            
            // and finally, upload the scan
            targetHost.submitScan(merged_scans);
            return;
        })
}

// standard module export boilerplate
if (typeof module !== "undefined" && module.exports) {
    module.exports = main;
}
