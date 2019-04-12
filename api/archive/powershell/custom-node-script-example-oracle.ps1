# Get-SPParameters.ps1
# Requires installation of Oracle Data Access Components
# It will be necessary to alter path to Oracle.DataAccess.dll

# Zakk Acreman <zakk.acreman@upguard.com>
# Forward Deployed Engineer, UpGuard Inc.

Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$connString
)

# Load Oracle DataAccess Components
Add-Type -Path "C:\Path\To\oracle\product\12.1.0\client_1\odp.net\bin\4\Oracle.DataAccess.dll" 

# Open connection
$conn = New-Object Oracle.DataAccess.Client.OracleConnection($connString)
$conn.Open()

$node = @{}

# For a consistently well-formatted custom node, returned JSON
# structure should look like:

# { section_header: {
#   subsection_header: {
#     configuration_item_1: {
#       attr_1: "value",
#       attr_2: "value"
#     },
#     configuration_item_2: {
#       attr_1: "other value",
#       attr_2: "other value"
#     }
#   }
# }

# "section_header" will be used as the top-level name for a group of
# CIs.

# "subsection_header" will be part of the CI path for policy building.
# It is hidden from the node scan visualization if there is only one
# subsection in a section, but it still has to exist.
#
# This is frequently the operating system producing the CIs. For
# example, in a Windows node scan, the structure of the Files section
# looks like this:
# files -> windows -> %windir%\example.ini

# "configuration_item" is the name of the CI, represented as a gray
# square in the UpGuard node scan visualization. Its child should
# always be an object mapping attribute names to values. It should
# never be a single value.

# The following Powershell creates a "version" section with a single
# CI based on the output of one SQL query, and a "SPParameters"
# section with multiple CIs based on the output of a different SQL
# query.


#
# Version
#

$version_hash = @{}

$sql = "SELECT COMMENTS FROM dba_registry_history WHERE ACTION_TIME=(SELECT MAX(ACTION_TIME) FROM dba_registry_history WHERE comments LIKE '%PSU%')"

$command = New-Object Oracle.DataAccess.Client.OracleCommand($sql, $conn)

$reader = $command.ExecuteReader()

$reader.Read() # Only one entry
$version_string = $reader["COMMENTS"]

$version_hash.add("Version", @{"Value" = $version_string})

$reader.Close()

$node.add("Version", @{"Oracle" = $version_hash})


#
# SPParameters
#

$sql = "SELECT NAME, SID, VALUE, UPDATE_COMMENT FROM V`$SPPARAMETER WHERE ISSPECIFIED='TRUE'"

$command = New-Object Oracle.DataAccess.Client.OracleCommand($sql, $conn)

$reader = $command.ExecuteReader()

$spparams = @{}

$spparam_keys = @{}
while ($reader.Read())
{
    $key = $reader["NAME"]
    $attr = @{"SID" = $reader["SID"];
              "VALUE" = $reader["VALUE"];
              "UPDATE_COMMENT" = if ($reader["UPDATE_COMMENT"]) {$reader["UPDATE_COMMENT"]} else { "" }}
    
    if ($spparam_keys[$key]) { # Key already exists
        if ($spparam_keys[$key] -eq 1) {
            $old_val = $spparams[$key]
            $new_old_key = $key + "_0"
            $spparams.add($new_old_key, $old_val)
            $spparams.remove($key)
        }
        $new_key = $key + "_" + $spparam_keys[$key]
        $spparams.add($new_key, $attr)      
        $spparam_keys[$key] = $spparam_keys[$key] + 1
        
    } else {
        $spparam_keys.add($key, 1)
        $spparams.add($key, $attr)
    }
}

$reader.Close()

$node.add("SPParameters", @{"Oracle" = $spparams})

#
# Teardown
#
$conn.Close()

return $node | ConvertTo-JSON -depth 10
