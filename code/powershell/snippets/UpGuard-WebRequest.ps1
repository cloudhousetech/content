# Perform an API request and return the result as a Powershell object
# If you need to handle pagination, you can provide the Paginate switch with a CombineAttribute if you
#   need to combine pages on a specific attribute
# For example, the /api/v2/nodes.json endpoint returns a list so pages can be combined and return a list
#   just by passing the Paginate switch
# Alternatively, the /api/v2/diffs.json endpoint returns statistics along with a "diff_items" attribute
#     which contains the list of diffs. Passing the Paginate switch with "diff_items" for CombineAttribute
#     will return a usable list
function UpGuard-WebRequest
{
    param
    (
      [string]$Method = 'Get',
      [string]$Endpoint,
      [string]$ApiKey,
      [string]$SecretKey,
      [hashtable]$Body = @{},
      [switch]$Paginate,
      [string]$CombineAttribute = "" # To paginate, provide the attribute to combine multiple results
    )

    # Handle very large JSON responses (such as scan data)
    # [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    # $jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    # $jsonserial.MaxJsonLength  = 67108864

    $headers = @{'Authorization' = "Token token=""$($ApiKey)$($SecretKey)"""}
    if ($Paginate) {
      $result = @()
      if ($Body.Keys -notcontains "page") { $Body.page = 1 }
      if ($Body.Keys -notcontains "per_page") { $Body.per_page = 50 }
      while ($true) {
        $new = Invoke-WebRequest -Method $Method -Uri $Endpoint -Headers $headers -Body $Body -ContentType "application/json"
        if ($new.StatusCode > 400){throw [System.Exception] "$($new.StatusCode.ToString()) $($new.StatusDescription)"}
        $new = ConvertFrom-Json $new.Content

        if ($CombineAttribute -ne "") {
          $new = $new | Select -ExpandProperty $CombineAttribute

          $result += $new
          if ([int]$new.Count -lt [int]$Body.per_page) { return $result}
        }
        else {
          # No CombineAttribute was provided
          $result += $new
          if ([int]$new.Count -lt [int]$Body.per_page) { return $result }
        }
        $Body.page = [int]$Body.page + 1
      }
    }
    if ($Method -in "Get","Delete"){$req = Invoke-WebRequest -Method $Method -Uri $Endpoint -Headers $headers -ContentType "application/json"}
    else{$req = Invoke-WebRequest -Method $Method -Uri $Endpoint -Headers $headers -Body $Body -ContentType "application/json"}
    if ($req)
    {
      if ($req.StatusCode > 400){throw [System.Exception] "$($req.StatusCode.ToString()) $($req.StatusDescription)"}
      # else{return $jsonserial.DeserializeObject($req.Content)}
      else { return ConvertFrom-Json $req.Content }
    }
}
