using module '.\module\Common.psm1'
#region: variable
$configFilePath = "$PSScriptRoot\config\GetAzureResourceDotProperty.config.json"
$ErrorActionPreference = 'Continue'
$global:logfilePath = "$PSScriptRoot\{0}.log" -f (Get-LocalDateTime).ToString("yyyyMMddHHmmss")
$outFilePath = "$PSScriptRoot\{0}_dotProperties.csv" -f (Get-LocalDateTime).ToString("yyyyMMddHHmmss")
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
$parameter = @{
    Uri    = "https://login.microsoftonline.com/$($global:config.authentication.tenantId)/oauth2/token"
    Method = "Post"
    Body   = @{
        grant_type    = "client_credentials"
        client_id     = $global:config.authentication.client_id
        client_secret = $global:config.authentication.client_secret
        resource      = "https://management.azure.com/"
    }
}
$response = Invoke-RestMethod @parameter
$global:headers = @{
    Authorization = "Bearer " + $response.access_token
    Accept        = "application/json"
}
Write-Log -Message "[Info]finish to get bearer token and set if for headers"
#endregion

#region: Get Resource Ids
Write-Log -Message "[Info]start to get id of resourcs"
$parameter = @{
    Uri         = "https://management.azure.com/subscriptions/$($global:config.subscriptionId)/resources?api-version=2021-04-01"
    Method      = "Get"
    Headers     = $global:headers
    ContentType = "application/json;charset=utf-8"
}
$response = Invoke-RestMethod @parameter
$resources = $response.value | Where-Object { ($global:config.resourceProperties.type) -contains $_.type } | Select-Object id, type
Write-Log -Message "[Info]finish to get id of resources"
#endregion

#region: Get Resource Property
Write-Log -Message "[Info]start to get properties of resources"
$resourceProperties = [ordered]@{"resources" = [System.Collections.ArrayList]::new() }
foreach ($resource in $resources) {
    $apiVersion = ($global:config.resourceProperties | Where-Object { $_.type -eq $resource.type }).apiVersion
    $parameter = @{
        Uri           = "https://management.azure.com/$($resource.id)?api-version=$apiVersion"
        Method        = "Get"
        Headers       = $global:headers
        ContentType   = "application/json;charset=utf-8"
    }
    $response = Invoke-RestMethod @parameter
    $resourceProperties.resources.Add($response) | Out-Null
}
Write-Log -Message "[Info]finish to get properties of resources"
#endregion

#region: Convert to dot property
Write-Log -Message "[Info]start to convert to dot property"
$dotProperties = [System.Collections.ArrayList]::new()
foreach ($resourceProperty in $resourceProperties.resources) {
    $dotProperty = ConvertTo-DotProperty -item $resourceProperty -prefix ""
    foreach ($item in $dotProperty) {
        $record = [ordered]@{
            resourceId   = $resourceProperty.id
            resourceType = $resourceProperty.type
            key          = $item -replace "^(?<key>[^:]+)(?=:):(?<value>.+)$", "`${key}"
            value        = $item -replace "^(?<key>[^:]+)(?=:):(?<value>.+)$", "`${value}"
        }
        $dotProperties.Add($record) | Out-Null
    }
}
Write-Log -Message "[Info]finish to convert to dot property"
#endregion

#region: Export to dot property
Write-Log -Message "[Info]start to Export dot property to csv"
foreach ($item in $global:config.resourceProperties) {
    if (!$item.ContainsKey("visible") -or [System.String]::IsNullOrEmpty($global:config.resourceProperties.visible)) {
        # visible Keyが存在しないまたはvisible Keyに値が何も含まれていない場合には、全てをエクスポートする
        # エクスポート不要なのであれば、Configから項目ごと消せばよい
        # resourceType列の削除とCSV出力
        $exportDotProperties = $dotProperties | Where-Object { $item.type -eq $_.resourceType }
        $exportDotProperties | ForEach-Object { $_.Remove("resourceType") }
        $exportDotProperties | ConvertTo-Csv -NoHeader | Out-File -FilePath $outFilePath -Encoding utf8 -Append
    }
    else {
        # visible Keyに設定されている項目のみを出力する
        # resourceType列の削除とCSV出力
        $exportDotProperties = $dotProperties | Where-Object { $item.type -eq $_.resourceType -and (Compare-DotProperty -visible $item.visible -dotPropertyKey $_.key) }
        $exportDotProperties | ForEach-Object { $_.Remove("resourceType") }
        $exportDotProperties | ConvertTo-Csv -NoHeader | Out-File -FilePath $outFilePath -Encoding utf8 -Append
    }
}
Write-Log -Message "[Info]finish to Export dot property to csv"
#endregion

Write-Log -Message "[Info]finish main logic"
#endregion