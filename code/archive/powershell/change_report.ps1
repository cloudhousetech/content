Param(
    [Parameter(Mandatory=$False)]
    [string]$dateFromInput,
    [Parameter(Mandatory=$False)]
    [string]$dateToInput
)
#This script counts the number of diffs returned by /api/v2/change_report.json
#It grabs the results from the beginning of the previous day at 12am to the time of execution
#Pagination with a limit of 5000 items per page is used in order to load all results
#
#--Flags
# -dateFromInput and -dateToInput can be used as flags to set the date range
#  EX: ./filepath/diff.ps1.txt -dateFromInput 2017-07-01 -dateToInput 2017-07-02
#
# the date range must be in ISO 8601 format with yyyy-mm-dd with an option Thh:mm appended at the back with T for time
#  EX: 2017-08-01 August 1st 2017 at 12AM
#  EX: 2017-08-01T20:10 same date at 8:10PM

$DebugOutput = $true
$DisableCertCheck = $true

$secret_key = '' #secret key shown when API enabled in Manage Accounts | Account | enable api access
$api_key = '' #service Api key under Manage Accounts | Account 
$url = '' #Example: 123.0.0.1:3000
$scheme = 'http'


function Write-OptionalDebug {
    param([string]$output)
    if ($DebugOutput) {
        Write-Host $output
    }
}

function Invoke-UpGuardApi {
    param(
        [string]$Url = $url,
        [string]$SecretKey = $secret_key,
        [string]$ApiKey = $api_key,
        [string]$RequestPath = $null,
        [string]$FullPath = $null,
        [string]$Scheme = $scheme,
        [string]$Method = "GET",
        [bool]$Raw = $false
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

    $req = Invoke-WebRequest -Uri $uri -Method $Method -Headers $headers -UseBasicParsing

    Write-OptionalDebug "Got status code $($req.StatusCode)"

    if ($req.StatusCode -gt 400) {
        throw [System.Exception] "$($req.StatusCode) $($req.StatusDescription)"
    }

    if ($Raw) {
        $req.Content
    } else {
        
        $content = $req.Content
        $content = $content.ToString().Replace("""Name""", """name""")
        #$content | ConvertFrom-Json
        $json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
        $json.MaxJsonLength = 104857600 #100mb as bytes, default is 2mb
        $data = $json.Deserialize($content, [System.Object])
        $data
    }
}


function Start-Main {
    if($($dateFromInput) -eq "") {
        $fromDate = Get-Date -format s (Get-Date).AddDays(-1) #get 24 hours from execution
        $fromDate = $($fromDate).split("T")[0] #remove old time
        $fromDate = "$($fromDate)T00:00" #add beginning of day time
    } else {
        $fromDate = $($dateFromInput)
    }

    if($($dateToInput) -eq "") {
        $toDate = Get-Date -format s
    } else {
        if($($dateFromInput) -eq "") {
            Write-Output "Please enter a dateFromInput in addition a dateToInput"
            exit
        }
        $toDate = $($dateToInput)
    }
    Write-Output "Reporting diffs from $($fromDate) to $($toDate)"
    $page = 0
    $limit =5000
    $diff_hash = @{}
    $last_count = 1
    while($last_count -ne 0) {
        $json = Invoke-UpGuardApi -RequestPath "api/v2/change_report.json?date_from=$($fromDate)&date_to=$($toDate)&page=$($page)&limit=$($limit)"
        $diff_items = $json.diff_items
        $last_count = $diff_items.Count
        ForEach($diff in $diff_items) {
            $name = "$($diff.type)-$($diff.node_name)-$($diff.name)" #Filters changes by CI type, node name, and CI type
            if($diff_hash[$name] -eq $null) {
                $diff_hash.Add($name, 1)
            } else {
                $diff_hash[$name] = $diff_hash[$name] + 1
            }
        }
        $page += 1
    }
    
    if($diff_hash.Count -eq 0) {
        Write-Output "There were no diffs from $($fromDate) to $($toDate)"
    } else {
        $diff_hash = $diff_hash.GetEnumerator() | Select-Object  @{Label='Node Type-Node Name';Expression={$_.Key}}, @{Label='Diff Count';Expression={$_.Value}}
        $diff_hash.GetEnumerator() | Sort-Object 'Diff Count' -Descending  | Write-Output
    }
}

Start-Main
