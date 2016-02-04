function parseIIS($section, $keyName) {
    $results = @{}
    foreach ($i in $section) {
        $obj = @{}
        foreach ($attr in $i.Attributes) {
            if ($attr.Name -ne $keyName) {
                if ($attr.Value) {
                    $obj[$attr.Name] = $attr.Value.ToString()
                }
            }
        }
        if ($i.$keyName) {
            $results[$i.$keyName] = $obj
        }
    }
    $results
}
[xml]$config = Get-Content C:\Windows\system32\inetsrv\config\applicationHost.config
$object = @{}
foreach ($site in $config.configuration.'system.applicationHost'.sites.site) {
    $appls = $site.application
    foreach ($appl in $appls) {
        $application = @{}
        foreach ($attr in $appl.Attributes) {
            if ($attr.Value) {
                $application[$attr.Name] = $attr.Value.ToString()
            }
        }
        if ($appl.VirtualDirectory) {
            $virtualDirectory = @{}
            foreach ($vattr in $appl.VirtualDirectory.Attributes) {
                if ($vattr.Value) {
                    $virtualDirectory[$vattr.Name] = $vattr.Value.ToString()
                }
            }
            $application['virtualDirectory'] = $virtualDirectory
        }
        $parentName = $appl.ParentNode.Name -replace ' '
        if ($object.ContainsKey($parentName) -ne $true) {
            $object[$parentName] = @{}
        }
        if ($appl.path) {
            $object[$parentName][$appl.path] = $application
        }
    }
}
$logs = @{}
$object['logs'] = $logs
foreach ($l in $config.configuration.'system.applicationHost'.log.centralBinaryLogFile) {
    $log = @{}
    foreach ($attr in $l.Attributes) {
          if ($attr.Value) {
              $log[$attr.Name] = $attr.Value.ToString()
          }
    }
    $logs['centralBinaryLogFile'] = $log
}
foreach ($l in $config.configuration.'system.applicationHost'.log.centralW3CLogFile) {
    $log = @{}
    foreach ($attr in $l.Attributes) {
          if ($attr.Value) {
              $log[$attr.Name] = $attr.Value.ToString()
          }
    }
    $logs['centralW3CLogFile'] = $log
}
Import-Module WebAdministration -ErrorAction SilentlyContinue
$object['applicationPools'] = @{} 
$pools = Get-ChildItem iis:\apppools -ErrorAction SilentlyContinue
if ($pools) {
    foreach ($p in $pools) {
        $pool = @{}
        foreach ($a in $p.Attributes) {
            if ($a.Name -eq 'name') { continue; }
            if ($a.Value) {
                $pool[$a.Name] = $a.Value.ToString();
            }
        }
        if ($p.Name) {
            $object['applicationPools'][$p.Name] = $pool;
        }
    }
}
$object['sites'] = @{}
$sites = Get-ChildItem iis:\sites -ErrorAction SilentlyContinue
if ($sites) {
    foreach ($s in $sites) {
        $site = @{}
        foreach ($a in $s.Attributes) {
            if ($a.Name -eq 'name') { continue; }
            if ($a.Value) {
                $site[$a.Name] = $a.Value.ToString();
            }
        }
        $bindings = @{}
        foreach ($b in $s.bindings.Collection) {
            $bind = @{}
            foreach ($a in $b.Attributes) {
                if ($a.Name -eq 'bindingInformation') { continue; }
                if ($a.Value) {
                  $bind[$a.Name] = $a.Value.ToString();
                }
            }
            $bindings[$b.bindingInformation] = $bind
        }
        $site['bindings'] = $bindings;
        if ($s.Name) {
          $object['sites'][$s.Name] = $site;
        }
    }
}
$ddFiles = @{}
$object['defaultDocumentFiles'] = $ddFiles
foreach ($f in $config.configuration.'system.webServer'.defaultDocument.files.add) {
    if ($f.Value) {
        $ddFiles[$f.Value] = @{ 'present' = 'true' }
    }
}
$object['system.webServer'] = parseIis $config.configuration.'system.webServer'.ChildNodes 'name'
$object['globalModules'] = parseIis $config.configuration.'system.webServer'.httpErrors.error 'name'
$object['httpErrors'] = parseIis $config.configuration.'system.webServer'.httpErrors.error 'statusCode'
$object['fileExtensions'] = parseIis $config.configuration.'system.webServer'.security.requestFiltering.fileExtensions.add 'fileExtension'
$object['mimeMaps'] = parseIis $config.configuration.'system.webServer'.staticContent.mimeMap 'fileExtension'
$object['handlers'] = parseIis $config.configuration.location.'system.webServer'.handlers.add 'name'
$object['modules'] = parseIis $config.configuration.location.'system.webServer'.modules.add 'name'
$object['configProtectedData'] = parseIis $config.configuration.configProtectedData.providers.add 'name'
add-type -assembly system.web.extensions
$ps_js=new-object system.web.script.serialization.javascriptSerializer
$ps_js.Serialize($object)

