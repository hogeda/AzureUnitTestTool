using module '.\module\Common.psm1'
#region: variable
$configFilePath = "$PSScriptRoot\config\GetAzureResourceDotProperty.config.json"
$ErrorActionPreference = 'Continue'
$global:logfilePath = "$PSScriptRoot\{0}.log" -f (Get-LocalDateTime).ToString("yyyyMMddHHmmss")
$outputFolderPath = "$PSScriptRoot\output\{0}" -f (Get-LocalDateTime).ToString("yyyyMMddHHmmss")
$global:config = ""
$global:headers = ""
#endregion

#region: Main
Write-Log -Message "[Info]start main logic"

#region: Read Config File
Write-Log -Message "[Info]start to read the config file"
$global:config = Get-Content -Path $configFilePath -Encoding utf8 | ConvertFrom-Json -AsHashtable
Write-Log -Message "[Info]finish to read the config file"
#endregion

#region: Get Bearer token and Set headers
Write-Log -Message "[Info]start to get bearer token and set it for headers"
$global:headers = Get-AuthorizationHeader `
    -tenantId $global:config.authentication.tenantId `
    -clientId $global:config.authentication.clientId `
    -clientSecret $global:config.authentication.clientSecret
Write-Log -Message "[Info]finish to get bearer token and set if for headers"
#endregion

#region: Get Resources
Write-Log -Message "[Info]start to get id of resources"
$resources = Get-Resources -subscriptionId $global:config.subscriptionId -resourceTypes @($global:config.resourcesProperty.type)
Write-Log -Message "[Info]finish to get id of resources"
#endregion

#region: Get Resource Property
Write-Log -Message "[Info]start to get resource property"
$resourcesProperty = [System.Collections.ArrayList]::new()
foreach ($resource in $resources) {
    $apiVersion = ($global:config.resourcesProperty | Where-Object { $_.type -eq $resource.type }).apiVersion
    $resourceProperty = Get-ResourceProperty -resourceId $resource.id -apiVersion $apiVersion
    $resourcesProperty.Add($resourceProperty) | Out-Null
}
Write-Log -Message "[Info]finish to get resource property"
#endregion

#region: Convert ARM into dot notation
Write-Log -Message "[Info]start to convert ARM into dot notation"
$dotNotations = [System.Collections.ArrayList]::new()
foreach ($resourceProperty in $resourcesProperty) {
    $dotNotation = ConvertTo-DotNotation -inputObject $resourceProperty -prefix "" -returnAsOrderedDictionary
    $dotNotations.Add($dotNotation) | Out-Null
}
Write-Log -Message "[Info]finish to convert ARM into dot notation"
#endregion

#region: Out File
Write-Log -Message "[Info]start to out files"
if (!(Test-Path $outputFolderPath)) {
    New-Item -ItemType Directory -Path $outputFolderPath | Out-Null
}

# dotnotation
'"SearchString","Value"' | Out-File -FilePath "$($outputFolderPath)/dotNotation.csv" -Encoding utf8 -Append
foreach ($dotNotation in $dotNotations) {
    $resourceType = $dotNotation.type
    $resourceId = $dotNotation.id
    $resourcePropertyConfig = $global:config.resourcesProperty | Where-Object { $_.type -eq $resourceType }
    # dotNotation
    if (!$resourcePropertyConfig.ContainsKey("visible") -or [System.String]::IsNullOrEmpty($resourcePropertyConfig.visible)) {
        $dotNotation.GetEnumerator() `
        | Select-Object @{Name="SearchString";Expression={"$($resourceId).$($_.Key)"}}, Value `
        | ConvertTo-Csv -NoHeader `
        | Out-File -FilePath "$($outputFolderPath)/dotNotation.csv" -Encoding utf8 -Append
    }
    else {
        $visible = $resourcePropertyConfig.visible
        $dotNotation.GetEnumerator() `
        | Where-Object { Compare-DotNotation -visible $visible -dotNotationKey $_.Key } `
        | Select-Object @{Name="SearchString";Expression={"$($resourceId).$($_.Key)"}}, Value `
        | ConvertTo-Csv -NoHeader `
        | Out-File -FilePath "$($outputFolderPath)/dotNotation.csv" -Encoding utf8 -Append
    }
}

# resourceType
'"ResourceType","DotNotation"' | Out-File -FilePath "$($outputFolderPath)/resourceType.csv" -Encoding utf8 -Append
foreach($resourceType in @($dotNotations.type | Select-Object -Unique)){
    $visible = ($global:config.resourcesProperty | Where-Object { $_.type -eq $resourceType}).visible
    $allKeys = ($dotNotations | Where-Object { $_.type -eq $resourceType}).Keys | Select-Object -Unique
    $allKeys = Optimize-DotNotationKey -item $allKeys -prefix ""
    $visibleKeys = $allKeys | Where-Object { Compare-DotNotation -visible $visible -dotNotationKey $_}
    $visibleKeys `
    | Select-Object @{Name="ResourceType";Expression={$resourceType}},@{Name="DotNotation";Expression={$_}} `
    | ConvertTo-Csv -NoHeader `
    | Out-File -FilePath "$($outputFolderPath)/resourceType.csv" -Encoding utf8 -Append
}

# resourceId
'"ResourceType","ResourceId"' | Out-File -FilePath "$($outputFolderPath)/resourceId.csv" -Encoding utf8 -Append
foreach($resourceType in @($dotNotations.type | Select-Object -Unique)){
    $resourceId = ($dotNotations | Where-Object {$_.type -eq $resourceType}).id
    $resourceId `
    | Select-Object @{Name="ResourceType";Expression={$resourceType}},@{Name="ResourceId";Expression={$_}}
    | ConvertTo-Csv -NoHeader
    | Out-File -FilePath "$($outputFolderPath)/resourceId.csv" -Encoding utf8 -Append
}

Write-Log -Message "[Info]finish to out files"
#endregion

Write-Log -Message "[Info]finish main logic"
#endregion