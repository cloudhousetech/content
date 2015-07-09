$fimDataFolder = 'C:\Program Files (x86)\ScriptRockFIMScanner-1.0\Output'
$dataFiles = (Get-ChildItem $fimDataFolder | Where { $_.Extension -eq '.fim' } | Sort-Object)
$discoveredFiles = @{}
$sortableFiles = @()
$currentIndex = 1
$finalOutput = ''

if((Get-Service 'ScriptRock FIM').Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
    Stop-Service -DisplayName 'ScriptRock FIM'

    Start-Sleep -s 10

    Start-Service -DisplayName 'ScriptRock FIM'
}

foreach($dataFile in $dataFiles) {

    # last one should be in use
    if($currentIndex -ge $dataFiles.Length) {
        break
    }

    foreach($row in Import-Csv $dataFile.FullName) {
        $key = ''

        switch ($row.'Change Type') {
            'CREATE' { $key = $row.File }
            'CHANGE' { $key = $row.File }
            'RENAME' { $key = $row.'Old Value' }
            'DELETE' { $key = $row.'Old Value' }
        }

        if ($discoveredFiles.ContainsKey($key)) {
            if (($discoveredFiles[$key] -contains $row.'Change Type') -eq $FALSE) {
                $discoveredFiles[$key] += $row.'Time Stamp';
                $discoveredFiles[$key] += $row.'Change Type';
            }
        } else {
            $discoveredFiles.Add($key, @($row.'Time Stamp', $row.'Change Type'))
        }
    }

    Remove-Item $dataFile.FullName
    $currentIndex++
}

foreach ($kvp in $discoveredFiles.GetEnumerator()) {
    $entry = $kvp.Key + ' '

    foreach($c in $kvp.Value) {
        $entry += $c + ' '
    }

    $entry += "`r`n"
    $sortableFiles += $entry
}

$sortableFiles = ($sortableFiles | Sort-Object)

foreach ($f in $sortableFiles) {
    $finalOutput += $f
}

if((Get-Service 'ScriptRock FIM').Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
    Start-Service -DisplayName 'ScriptRock FIM'
}

$output = "" | Select folder, raw
$output.folder = 'FIM'
$output.raw    = $finalOutput

$output
