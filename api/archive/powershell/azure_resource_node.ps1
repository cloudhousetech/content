param(
    [string]$ResourceGroupName = '',
    [string]$AzureUserName = '',
    [string]$AzurePasswordFile = ''
)

$potato = ''

function EnsureProperty($obj, $name) {
    if(-Not (Get-Member -InputObject $obj -Name $name)) {
        $obj | Add-Member -MemberType NoteProperty -Name $name -Value (New-Object Object)
    }
    $obj
}

function BasicArrayToHash($array) {
    $hash = @{}
    $currentIndex = 0
    foreach($item in $array) {
        $hash[$currentIndex.ToString()] = $item
        $currentIndex = $currentIndex + 1
    }
    $hash
}

# "Smart"
function SmartArrayToHash($array) {
    $hash = @{}
    $currentIndex = 0
    foreach($item in $array) {
        $actualVal = $item
        $valuePropName = 'Value'
        $itemProps = (Get-Member -InputObject $item -MemberType Properties)

        # if it has only two properties and one is "Name", assume the other one is a value
        if($itemProps.Length -eq 2 -and (Get-Member -InputObject $item -Name "Name")) {
            $valuePropName = ($itemProps | Where { $_.Name -ne 'Name' } | Select Name).Name
        }

        # if it is a list of name-value pairs, use the "value" as the value
        if(Get-Member -InputObject $item -Name $valuePropName) {
            $actualVal = $item.Value
        } else {
            $actualVal = (Recombobulate $item)
        }

        # if it has a name, use that as the key
        if(Get-Member -InputObject $item -Name "Name") {
            $hash[$item.Name] = $actualVal
        } else {
            $hash[$currentIndex.ToString()] = (Recombobulate $item)
        }
        $currentIndex = $currentIndex + 1
    }
    $hash
}

function ValueToHash($value) {
    @{ 'Value' = $value }
}

function IsPrimitiveOrString($obj) {
    ($obj -eq $null -or $obj.GetType().IsPrimitive -or $obj -is [System.String])
}

# For objects that are not strings, but have a string-like output value
function HasStringLikeValue($obj) {
    ($obj.ToString() -eq $obj -or $obj.ToString() -eq '')
}

function IsCollection($obj, $excludeHashes = $false) {
    if($obj -eq $null) {
        return $false
    }
    if($obj -is [System.Array]) {
        return $true
    }
    if($excludeHashes -and $obj -is [HashTable]) {
        return $false
    }
    foreach($iFace in $obj.GetType().ImplementedInterfaces) {
        if ($iFace.Name -like 'IList' -or $iFace.Name -like 'IEnumerable' -or $iFace.Name -like 'ICollection') {
            return $true
        }
    }
    return $false
}

# Simply copy the values from one object to another, but more importantly use the default serialization strategy of a normal object
function Recombobulate($obj) {
    $safeObj = New-Object Object
    foreach($prop in $obj.psobject.properties) {
        $safeObj | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
    }

    $safeObj
}

function MakeBlueprintSafe($obj) {
    $safeObj = New-Object Object
    foreach($prop in $obj.psobject.properties) {
        if($prop.Value -is [System.Array] -and $prop.Value.Length -le 0) {
            $safeObj | Add-Member -MemberType NoteProperty -Name $prop.Name -Value (ValueToHash $prop.Value)
        }

        #if(-Not (IsPrimitiveOrString $prop.Value) -and $prop.Name -ne 'Value') {
        #    MakeBluePrintSafe($prop.Value)
        #}
    }

    $safeObj
}

function ExpandObjectForBluePrint($output, $obj, $propsRequiringSmartFunc=$null) {

    foreach($prop in $obj.PSObject.Properties) {
        Write-Debug $prop.Name
        if(IsCollection $prop.Value $true) {
            Write-Debug 'Collection'
            if($propsRequiringSmartFunc -and $prop.Name -in $propsRequiringSmartFunc) {
                $collectionResult = (SmartArrayToHash $prop.Value)
            } else {
                $collectionResult = (BasicArrayToHash $prop.Value)
            }

            # if this results in an empty hash, stick something in there
            if($collectionResult.Keys.Count -le 0) {
                $collectionResult = @{ 'Value' = '' }
            }

            $output | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $collectionResult
        } elseif ((IsPrimitiveOrString $prop.Value)) {
            Write-Debug 'Primitive'
            # we apparently do not represent null very well in the vis
            if($prop.Value -eq $null) {
                $output | Add-Member -MemberType NoteProperty -Name $prop.Name -Value @{ 'Value' = '' }
            } else {
                $output | Add-Member -MemberType NoteProperty -Name $prop.Name -Value (ValueToHash $prop.Value)
            }
        } else {
            Write-Debug 'Object'
            # hashes can probably just go in as they are
            if (IsCollection $prop.Value $false) {
                $output | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
            } else {
                $output | Add-Member -MemberType NoteProperty -Name $prop.Name -Value (Recombobulate $prop.Value)
            }
        }
    }

    $output
}

# When calling this, if the property exists on objA, it will be preserved and objB's version discarded
function MergeObjects($objA, $objB) {
    $mergedObj = New-Object Object

    if(-Not($objA)) {
        return $objB
    }

    if(-Not ($objB)) {
        return $objA
    }

    foreach($prop in $objA.PSObject.Properties) {
        $mergedObj | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
    }

    foreach($prop in $objB.PSObject.Properties) {
        if(-Not (Get-Member -InputObject $mergedObj -Name $prop.Name)) {
            $mergedObj | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
        }
    }

    $mergedObj
}

function GetCloudServicesInResourceGroup($resourceGroupName) {
    # There does not appear to be a more targeted version of this for resource groups
    $cloudServices = Get-AzureService
    $results = @()

    foreach($cs in $cloudServices) {
        if($cs.ExtendedProperties -and $cs.ExtendedProperties['ResourceGroup'] -eq $resourceGroupName) {
            $results += $cs
        }
    }

    $results
}

function HandleDomainName($resource, $output) {
    $output = EnsureProperty $output 'DomainNames'

    $dn = Get-AzureRmResource -ResourceGroupName $resource.ResourceGroupName -ResourceType 'Microsoft.ClassicCompute/domainNames' -ResourceName $resource.ResourceName
    $slots = Get-AzureRmResource -ResourceGroupName zt-cloudservice-deploy -ResourceType Microsoft.ClassicCompute/domainNames/slots -ResourceName zt-cloudservice-deploy
    $output.DomainNames = EnsureProperty $output.DomainNames 'Slots'
    $output.DomainNames = EnsureProperty $output.DomainNames 'Roles'
    foreach($slot in $slots) {
        # TODO: properties needs to be converted from XML
        $output.DomainNames.Slots = EnsureProperty $output.DomainNames.Slots $slot.Name
        $output.DomainNames.Slots."$($slot.Name)" = ExpandObjectForBlueprint $output.DomainNames.Slots."$($slot.Name)" $slot
        $roles = Get-AzureRmResource -ResourceGroupName $resource.ResourceGroupName -ResourceType 'Microsoft.ClassicCompute/domainNames/slots/roles' -ResourceName "$($resource.ResourceName)/$($slot.Name)/"
        foreach($role in $roles) {
            $output.DomainNames.Roles = EnsureProperty $output.DomainNames.Roles "$($slot.Name)-$($role.Name)"
            $output.DomainNames.Roles."$($slot.Name)-$($role.Name)" = ExpandObjectForBlueprint $output.DomainNames.Roles."$($slot.Name)-$($role.Name)" $role
        }
    }

    $output
}

function HandleVirtualMachines($resource, $output) {
    $output = EnsureProperty $output 'VirtualMachines'

    # urgh
    $appropriateCloudServices = GetCloudServicesInResourceGroup $resource.ResourceGroupName

    # try for new-style vm first
    $vm = Get-AzureRmVM -Name $resource.ResourceName -ResourceGroupName $resource.ResourceGroupName -ErrorAction SilentlyContinue

    # old style if that fails
    if(-Not ($vm)) {
        foreach($cs in $appropriateCloudServices) {
            $vm = Get-AzureVM -Name $resource.ResourceName -Service $cs.ServiceName

            if($vm) {
                break
            }
        }
    }

    if($vm) {
        $actualVMName = ''
        if (-Not (Get-Member -InputObject $vm -Name 'ResourceName')) {
            $actualVMName = $vm.Name
        } else {
            $actualVMName = $vm.ResourceName
        }

        $output.VirtualMachines = EnsureProperty $output.VirtualMachines $actualVMName
        $output.VirtualMachines."$($actualVMName)" = ExpandObjectForBlueprint $output.VirtualMachines."$($actualVMName)" $vm
    }

    $output
}

function HandleInsightsAlertRules($resource, $output) {
    $output = EnsureProperty $output 'AlertRules'

    foreach($rule in (Get-AlertRule -ResourceGroup $resource.ResourceGroupName)) {
        if(-Not (Get-Member -InputObject $output.AlertRules -Name $rule.Name)) {
            $output.AlertRules = EnsureProperty $output.AlertRules $rule.Name
            $output.AlertRules."$($rule.Name)" = ExpandObjectForBlueprint $output.AlertRules."$($rule.Name)" $rule.Properties
        }
    }

    $output
}

function HandleInsightsComponents($resource, $output) {
    $output = EnsureProperty $output 'Components'

    #Write-Host $resource

    $output
}

function HandleInsightsAutoScaleSettings($resource, $output) {
    $output = EnsureProperty $output 'AutoScaleSettings'

    # not that the cmdlet is Get-AutoscaleSetting, singular
    foreach($profile in (Get-AutoscaleSetting -ResourceGroup $resource.ResourceGroupName).Properties.Profiles) {
        if(-Not (Get-Member -InputObject $output.AutoScaleSettings -Name $profile.Name)) {

            $output.AutoScaleSettings | Add-Member -MemberType NoteProperty -Name $profile.Name -Value (New-Object Object)
            
            foreach($rule in $profile.Rules) {
                foreach($mt in $rule.MetricTrigger) {
                    $output.AutoScaleSettings."$($profile.Name)" | Add-Member -MemberType NoteProperty -Name "$($mt.MetricName) - $($mt.Statistic) - $($mt.Operator) - $($mt.Threshold)" -Value (ConvertTo-Json $mt)
                }

                foreach($sa in $rule.ScaleAction) {
                    $output.AutoScaleSettings."$($profile.Name)" | Add-Member -MemberType NoteProperty -Name "$($sa.Type) - $($sa.Direction) - $($sa.Value)" -Value (ConvertTo-Json $sa)
                }
            }
        }
    }

    $output
}

function HandleWebSites($resource, $output) {
    $output = EnsureProperty $output 'WebSites'

    $ws = Get-AzureWebSite -Name $resource.Name
    
    $specialFuncs = @{
        'HostNames' = $QuerySwaggerInformation
    }

    foreach($prop in $ws.PSObject.Properties) {
        if($prop.Value -is [System.Array] -and $prop.Value.Length -le 0) {
            continue
        }

        if($specialFuncs.ContainsKey($prop.Name)) {
            $output = (& $specialFuncs[$prop.Name] $output $prop)
        }
    }

    $output.WebSites = EnsureProperty $output.WebSites "$($resource.Name)"
    $output.WebSites."$($resource.Name)" = ExpandObjectForBlueprint $output.WebSites."$($resource.Name)" $ws @('MetaData', 'HostNameSslStates', 'Instances')
    $output = HandleWebsiteDeployments $output $resource
    
    $output
}

function HandleWebsiteDeployments($output, $resource) {

    $allDeployments = Get-AzureWebsiteDeployment -Name $resource.Name
    #$latestDeployment = Get-AzureWebsiteDeployment -Name $resource.Name | Where { $_.Current -eq $true }

    #$output = EnsureProperty $output "$($resource.Name)-LastDeployment"
    #$output."$($resource.Name)-LastDeployment" = (ExpandObjectForBlueprint $output."$($resource.Name)".LastDeployment $lastDeployment)

    $output = EnsureProperty $output "$($resource.Name)-AllDeployments"

    $deploymentList = New-Object Object

    foreach($deploy in $allDeployments) {
        $deploymentList | Add-Member -MemberType NoteProperty -Name "$($deploy.Id)" -Value (New-Object Object)
        #$deploymentList = GetCommitListForDeployment $deploymentList."$($deploy.Id)" $resource $deploymentList
        $deploymentList."$($deploy.Id)" = (ExpandObjectForBlueprint $deploymentList."$($deploy.Id)" $deploy)
    }

    $output."$($resource.Name)-AllDeployments" = $deploymentList

    $output
}

function GetCommitListForDeployment($output, $website, $deploymentList) {
    $repoApiUri = $website.MetaData | Where { $_.Name -eq 'RepoApiUri' }
    
    if($repoApiUri -and $repoApiUri.Value) {
        $pullListUri = ($repoApiUri.Value + '/pulls?state-closed')
        $pulls = Invoke-WebRequest -Uri $pullListUri -Method Get -Headers @{ 'Accept' = 'application/json' } | ConvertFrom-Json

        if($pulls) {
            $currentDeploy = $deploymentList | Where { $_.Current -eq $true }
            $previousDeploys = $deploymentList | Where { $_.LastSuccessEndTime -lt $currentDeploy.LastSuccessEndTime} | Sort -Property LastSuccessEndTime
            $previousSuccessfulDeploy = $previousDeploys[0]

            #include only merged PRs
        }
    }

    $output
}

# I am displeased by the need to define this as a scriptblock rather than a function
$QuerySwaggerInformation = {
    param($output, $obj)

    foreach($url in $obj.Value) {
        $swaggerUrl = "$url/swagger/docs/v1"
        try {
            $response = Invoke-WebRequest -Uri $swaggerUrl -Method Get -Headers @{ 'Accept' = 'application/json' }
        } catch {
            $output = EnsureProperty $output $swaggerUrl
            $output."$($swaggerUrl)" | Add-Member -MemberType NoteProperty -Name "Request Failed" -Value @{ 'Value' = "API Metadata not found, response code $($_.Exception.Response.StatusCode.Value__)" }
        }

        if($response) {
            $output = EnsureProperty $output $swaggerUrl
            $actualPathObject = @{}
            $parsedResponse = (ConvertFrom-Json $response)
            # split the paths out into 'request method url' chunks, for better visibility
            foreach($pathProp in $parsedResponse.paths.psobject.properties) {
                foreach($requestTypeProp in $pathProp.Value.psobject.properties) {
                    $actualPathObject.Add("$($requestTypeProp.Name.ToUpper()) $($pathProp.Name)", $requestTypeProp.Value)
                }
            }
            $parsedResponse.paths = $actualPathObject
            $parsedResponse.host = @{ 'Value' = $parsedResponse.host }
            $parsedResponse.swagger = @{ 'Value' = $parsedResponse.swagger }
            $parsedResponse.schemes = (BasicArrayToHash $parsedResponse.schemes)
            $output."$($swaggerUrl)" = $parsedResponse
        }
    }

    $output
}

function HandleApiApps($resource, $output) {
    $output = EnsureProperty $output $resource.Name

    $output
}

function HandleGenericResource($resource, $output, $typeName, $cmdletName) {
    
    if((Get-Command $cmdletName).Parameters['ResourceGroupName']) {
        $actualResource = & $cmdletName -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    } else {
        $actualResource = & $cmdletName -ResourceGroup $resource.ResourceGroupName -Name $resource.Name
    }

    $output = EnsureProperty $output $typeName
    $output."$typeName" = EnsureProperty $output."$typeName" "$($resource.Name)"

    $output."$typeName"."$($resource.Name)" = ExpandObjectForBlueprint $output."$typeName"."$($resource.Name)" $actualResource

    $output
}

function HandleUnknown($resourceTypeName, $output) {
    $output = EnsureProperty $output 'Preview'

    if(-Not (Get-Member -InputObject $output.Preview -Name $resourceTypeName)) {
        $tmp = '' | Select Type
        $tmp.Type = $resourceTypeName
        $output.Preview | Add-Member -MemberType NoteProperty -Name $resourceTypeName -Value $tmp
    }

    $output
}

function AuthenticateToAzure($uname, $passLocation) {

    try {
        $user = $uname
        $pw = ConvertTo-SecureString (Get-Content $passLocation) -AsPlainText -Force
        $cred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $user, $pw
        Login-AzureRmAccount -Credential $cred
        Add-AzureAccount -Credential $cred

        return $true
    } catch {
        return $false
    }
    return $false
}

function GetResourcesInGroup($resourceGroupName) {
    $azureResourceGroup = Get-AzureRmResourceGroup | Where { $_.ResourceGroupName -eq $resourceGroupName }
    # I cannot find a parameter set that get what I want using Get-AzureRmResource, so we'll have to go with this slightly clunky way
    $azureResource = Find-AzureRmResource -ResourceGroupNameContains $resourceGroupName | Where { $_.ResourceGroupName -eq $resourceGroupName }
    $azureResource
}

function main($resourceGroupName, $uname, $passLocation) {

    Import-Module Azure
    Import-Module AzureRM.Insights

    if(-Not (AuthenticateToAzure $uname $passLocation)) {
        return @{ 'Error' = @{ 'Message' = @{ 'Content' = 'Failed to Authenticate to Azure' } } } | ConvertTo-Json
    }

    $finalOutput = New-Object Object

    $webApps = Get-AzureRmWebApp -ResourceGroupName $resourceGroupName
    if($webApps) {
        $finalOutput = EnsureProperty $finalOutput 'WebApp'
        foreach($webApp in $webApps) {
            $finalOutput.WebApp = EnsureProperty $finalOutput.WebApp "$($webApp.SiteName)"
            $finalOutput.WebApp."$($webApp.SiteName)" = ExpandObjectForBlueprint $finalOutput.WebApp."$($webApp.SiteName)" $webApp
        }
    }

    $azureResource = GetResourcesInGroup $resourceGroupName
    
    foreach($ar in $azureResource) {
        foreach($rt in $ar.ResourceType.Split(' ')) {
            switch($rt) {
                'Microsoft.ClassicCompute/domainNames' { $finalOutput = (HandleDomainName $ar $finalOutput) }
                'Microsoft.ClassicCompute/virtualMachines' { $finalOutput = (HandleVirtualMachines $ar $finalOutput) }
                'Microsoft.Compute/virtualMachines' { $finalOutput = (HandleVirtualMachines $ar $finalOutput) }
                'Microsoft.insights/alertrules' { $finalOutput = (HandleInsightsAlertRules $ar $finalOutput) }
                'Microsoft.insights/components' { $finalOutput = (HandleInsightsComponents $ar $finalOutput) }
                'Microsoft.insights/autoscalesettings' { $finalOutput = (HandleInsightsAutoScaleSettings $ar $finalOutput) }
                'Microsoft.Web/sites' { $finalOutput = (HandleWebSites $ar $finalOutput) }
                #'Microsoft.AppService/apiapps' { $finalOutput = (HandleApiApps $ar $finalOutput) }
                'Microsoft.Network/networkInterfaces' { $finalOutput = (HandleGenericResource $ar $finalOutput 'NetworkInterfaces' 'Get-AzureRmNetworkInterface') }
                'Microsoft.Network/networkSecurityGroups' { $finalOutput = (HandleGenericResource $ar $finalOutput 'NetworkSecurityGroups' 'Get-AzureRmNetworkSecurityGroup') }
                'Microsoft.Web/serverFarms' { $finalOutput = (HandleGenericResource $ar $finalOutput 'AppServicePlans' 'Get-AzureRmAppServicePlan') }
                #'Microsoft.Network/loadBalancers' { $finalOutput = (HandleLoadBalancers $ar $finalOutput) }
                'Microsoft.Network/loadBalancers' { $finalOutput = (HandleGenericResource $ar $finalOutput 'LoadBalancers' 'Get-AzureRmLoadBalancer') }
                'Microsoft.Network/publicIPAddresses' { $finalOutput = (HandleGenericResource $ar $finalOutput 'PublicIPAddresses' 'Get-AzureRmPublicIpAddress') }
                'Microsoft.Network/virtualNetworks' { $finalOutput = (HandleGenericResource $ar $finalOutput 'VirtualNetworks' 'Get-AzureRmVirtualNetwork') }
                'Microsoft.Storage/storageAccounts' { $finalOutput = (HandleGenericResource $ar $finalOutput 'StorageAccounts' 'Get-AzureRmStorageAccount') }
                'Microsoft.Compute/availabilitySets' { $finalOutput = (HandleGenericResource $ar $finalOutput 'AvailabilitySets' 'Get-AzureRmAvailabilitySet') }
                default { $finalOutput = HandleUnknown $rt $finalOutput }
            }
        }
    }

    $finalOutput | ConvertTo-Json -Compress -Depth 10
}

main $ResourceGroupName $AzureUserName $AzurePasswordFile

# Get-Module -ListAvailable | Where { $_.Name -like 'Azure*' } | Foreach-object { Get-Command -Module $_ } | Where { $_.Name -like 'Get*' }
