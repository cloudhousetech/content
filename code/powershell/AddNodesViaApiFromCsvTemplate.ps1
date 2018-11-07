#
# ------------------------------------------------------------------ 
# Notes
# ------------------------------------------------------------------
#
# This script will import nodes from the standard CSV template into UpGuard
# It gives you a little more control over the logic around node addition,
# and can form a foundation of a script to fully automate node addition.
#
# Key Medium Types
# ---------------
# AGENT    = 1
# SSH      = 3
# HTTPS    = 6
# WINRM    = 7
# DATABASE = 11
#
#
# Operating System Families: https://support.upguard.com/upguard/operating-system-families-api.html#index
# Operating Systems: https://support.upguard.com/upguard/operating-systems-api.html#index
# 


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$DebugOutput = $true    # Set to true for expanded logging
$TestRun     = $false   # API calls will be skipped if true

$secret_key  = '<INSERT_SECRET_KEY>'
$api_key     = '<INSERT_API_KEY>'
$site_url    = 'demo.upguard.com'
$scheme      = 'https'
$inputFile   = '<INSERT_INPUT_CSV_FILE_PATH>'

function Write-OptionalDebug {
    param([string]$output)
    if ($DebugOutput) {
        Write-Host $output
    }
}

function Invoke-UpGuardApi {
    param(
        [string]$Url = $site_url,
        [string]$SecretKey = $secret_key,
        [string]$ApiKey = $api_key,
        [string]$RequestPath = $null,
        [string]$FullPath = $null,
        [string]$Scheme = $scheme,
        [string]$Method = "GET",
        [bool]$Raw = $false,
        $Body = $null
    )

    if ($RequestPath -eq $null -and $FullPath -eq $null) {
        throw [System.Exception] "Must provide one of -RequestPath or -FullPath"
    }

    $headers = @{'Authorization' = 'Token token="' + $ApiKey + $SecretKey + '"'} #; 'Accept' = 'application/json'}
    Write-OptionalDebug "Req path: $RequestPath full path: $FullPath"
   
    $uri = ''

    if ($FullPath -ne $null -and $FullPath -ne '') {
        if (-not ($FullPath -match ".*\.json.*")) {
            $components = $FullPath.Split("?")
            $FullPath = "$($components[0]).json?$($components[1])"
        }
        $uri = $FullPath
    }
    else {
        $uri = "$($Scheme)://$Url/$RequestPath"
    }
    
    Write-OptionalDebug "Attempting to invoke $uri with $Method"

    if ($TestRun -ne $true) {
        $response = try { 
            if ($Body -ne $null) {
                $Body = ConvertTo-Json -InputObject $Body
                Invoke-WebRequest -ContentType 'application/json' -Uri $uri -Method $Method -Headers $headers -Body $Body -ErrorAction Stop
            } else {
                Invoke-WebRequest -ContentType 'application/json' -Uri $uri -Method $Method -Headers $headers -ErrorAction Stop
            }
        } catch [System.Net.WebException] { 
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            $respJson = ConvertFrom-Json $responseBody
            throw [System.Exception] "$($_.Exception.Response.StatusCode) $($_.Exception.Response.StatusDescription): $($respJson."error")"
        } 

        Write-OptionalDebug "Got status code $($response.StatusCode)"

        if ($req.StatusCode -gt 400) {
            throw [System.Exception] "$($response.StatusCode) $($response.StatusDescription)"
        }

        if ($Method -eq "GET") {
            if ($Raw) {
                $response.Content
            } else {
                $response.Content | ConvertFrom-Json
            }
        }
    }
}

function AddNode {
    param(
        [string]$name,
        [string]$nodeType,
        [string]$mediumType,
        [string]$mediumUsername = '',
        [string]$mediumPassword = '',
        [int]$mediumPort = '',
        [string]$mediumHostname = '',
        [string]$shortDesc = '',
        [int]$cmgId = $null,
        [int]$osfId,
        [int]$osId,
        [string]$url = '',
        [string]$externalId = '',
        [int]$environmentId
    )

    Write-OptionalDebug "Adding node $name"
    
    $hash = @{  
                name = $name;
                node_type = $nodeType;
                environment_id = $environmentId;
                operating_system_family_id = $osfId;
                operating_system_id = $osId;
                medium_type = $mediumType
                medium_username = $mediumUsername;
                medium_password = $mediumPassword;
                medium_hostname = $mediumHostname;
                medium_port = $mediumPort;
                external_id = $externalId;
                connection_manager_group_id = $cmgId;
                short_description = $shortDesc;
            }
    
    Invoke-UpGuardApi -RequestPath "api/v2/nodes.json" -Method 'POST' -Body @{ node = $hash }
}

function StartMain {
    foreach($line in Get-Content $inputFile) {
        $elements = $line.Split(",")

        # Extract key values
        $name              = $elements[0]
        $nodeType          = $elements[1]

        # Check if this is just a header row
        if ($name -eq 'name' -and $nodeType -eq 'node_type') { continue }

        $mediumType        = $elements[2]
        $mediumUsername    = $elements[3]
        $mediumPassword    = $elements[4]
        $mediumPort        = $elements[5]
        $mediumHostname    = $elements[6]
        $shortDesc         = $elements[7]
        $cmgId             = $elements[8]
        $osfId             = $elements[9]
        $osId              = $elements[10]
        $url               = $elements[11]  # Used for DB connection string
        $externalId        = $elements[12]
        $environmentId     = $elements[13]
        $targetNodeGroupId = $elements[14]
        # Edit here if additional fields are required (eg: WebSphere or Azure fields)
        
        Write-OptionalDebug "Processing node $name"
   
        AddNode $name $nodeType $mediumType $mediumUsername $mediumPassword $mediumPort $mediumHostname $shortDesc $cmgId $osfId $osId $url $externalId $environmentId

        Write-Output "Finished processing node $name"
        Write-Output ""
    }
}

StartMain
