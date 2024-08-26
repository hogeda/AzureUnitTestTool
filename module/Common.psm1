#region: variable
[string]$TimeDifference = "9:00"
[string[]]$TimeDiffHrsMin = "$($TimeDifference)".Split(':')
#endregion

<#
.SYNOPSIS
    現在時刻をUTC時刻で取得し、変数TimeDifferenceで指定された時間だけスライドさせることで、現在時刻を取得する。
.DESCRIPTION
    別途関数の外側でTimeDifference、TimeDiffHrsMinを定義してください。
.OUTPUTS
    Get-LocalDateTimeは現在時刻を返却します。
.EXAMPLE
    Get-LocalDateTime
#>
function Get-LocalDateTime {
    return (Get-Date).ToUniversalTime().AddHours($TimeDiffHrsMin[0]).AddMinutes($TimeDiffHrsMin[1])
}

<#
.SYNOPSIS
    指定されたメッセージを出力(Write-Output)します。
.DESCRIPTION
    指定されたメッセージを出力します。
    メッセージには、プレフィックスとして時刻、スクリプトファイル名、行番号が付与されます。
    Err、Warnスイッチを用いた場合には、追加で[Err]、[Warning]が付与されます。
.PARAMETER Message
    メッセージの本文
.PARAMETER Err
    エラースイッチ
.PARAMETER Warn
    警告スイッチ
.OUTPUTS
    明示的に返却するわけではないですが、メッセージがWrite-Outputされます。
    他の関数や、クラスのメソッド内で用いる場合には、コンソールに標準出力されるわけではないため気をつけてください。
.EXAMPLE
    Write-Log -Message "本文"
#>
function Write-Log {
    # Note: this is required to support param such as ErrorAction
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$Err,
        [switch]$Warn
    )
    [string]$MessageTimeStamp = (Get-LocalDateTime).ToString('yyyy-MM-dd HH:mm:ss')
    [string]$WriteMessage = "{0},{1}({2}),{3}" -f $MessageTimeStamp, (Split-Path -Path $MyInvocation.ScriptName -Leaf), $MyInvocation.ScriptLineNumber, $Message
    if ($Err) {
        Write-Output "[Error]$WriteMessage"
    }
    elseif ($Warn) {
        Write-Output "[Warning]$WriteMessage"
    }
    else {
        Write-Output $WriteMessage
    }
}

<#
.SYNOPSIS
    Bearer token を取得し、Authorization headerを返却します。
.DESCRIPTION
    引数の内容を元にアクセストークン要求を行い、Bearer tokenを取得します。
    取得した Bearer tokenはAzure REST API実行時の認証ヘッダー形式で返却します。
.PARAMETER tenantId
    Microsoft Entra ID のテナントID
.PARAMETER clientId
    サービスプリンシパルのクライアントID
.PARAMETER clientSecret
    サービスプリンシパルのシークレット
.OUTPUTS
    hashtable : Get-AuthorizationHeader はBearer tokenの認証ヘッダーを返却します。
    例）@{Authorization="Bearer <TOKEN>";Accept="application/json"}
.NOTES
    この関数はサービスプリンシパルの証明書認証には対応していません。
.EXAMPLE
    Get-AuthorizationHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret
#>
function Get-AuthorizationHeader {
    param (
        [string]$tenantId,
        [string]$clientId,
        [string]$clientSecret
    )
    $parameters = @{
        Uri    = "https://login.microsoftonline.com/$($tenantId)/oauth2/token"
        Method = "Post"
        Body   = @{
            grant_type    = "client_credentials"
            client_id     = $clientId
            client_secret = $clientSecret
            resource      = "https://management.azure.com/"
        }
    }
    $response = Invoke-RestMethod @parameters
    $headers = @{
        Authorization = "Bearer " + $response.access_token
        Accept        = "application/json"
    }
    return $headers
}

<#
.SYNOPSIS
    指定されたドット記法が指定された配列内に含まれるかを調べます。
.DESCRIPTION
    比較する際に、ドット記法の配列のインデックスは無視をします。
    そのためあらかじめvisibleで指定する配列のドット記法においては、配列のインデックスを削除しておいてください。
.PARAMETER visible
    ドット記法のリスト
.PARAMETER dotNotationKey
    ドット記法の文字列
.OUTPUTS
    boolean : Compare-DotNotation は指定された配列内にドット記法が含まれるかを調べて、論理型を返却します。
.EXAMPLE
    Compare-DotNotation -visible $visible -dotNotationKey $dotNotationKey
#>
function Compare-DotNotation {
    param(
        [String[]] $visible,
        [String] $dotNotationKey
    )
    if ($dotNotationKe -match "(?<=\[)\d+(?=\])") {
        return $visible -contains ($dotNotationKey -replace "(?<=\[)\d+(?=\])", "")
    }
    else {
        return $visible -contains $dotNotationKey
    }
}

<#
.SYNOPSIS
    オブジェクトのプロパティをドット記法で返却します。
.DESCRIPTION
    オブジェクトのプロパティの値がオブジェクトまたは配列である場合、再帰処理を用います。
    値が数字や文字列、論理値である場合は、ドット記法のプロパティをKey、その値をValueとして、
    返却用のOrderedDictionaryに要素を追加します。
.PARAMETER item
    ドット記法への変換を実施するオブジェクト
.PARAMETER prefix
    ドット記法する際のプレフィックス
.OUTPUTS
    OrderedDictionary: ConvertTo-DotNotationはドット記法のプロパティ名をKeyに、その値をValueにセットしたコレクションを返却します
.EXAMPLE
    ConvertTo-DotNotation -item $item -prefix $prefix
#>
function ConvertTo-DotNotation {
    # 関数のパラメータ
    param (
        [object] $item,
        [string] $prefix
    )
    # 戻り値の動的配列を宣言
    $output = [ordered]::new()    
    if (
        $item -is [string] -or 
        $item -is [int] -or 
        $item -is [long] -or 
        $item -is [float] -or 
        $item -is [double] -or 
        $item -is [decimal]
    ) {
        # $itemが文字列または数字であれば、戻り値の変数に値をセット
        $propertyName = $prefix
        $output.Add($propertyName, $item)
    }
    else {
        # $itemが文字列または数字でなければ、$itemが有するPropertyの種類に応じて処理を分ける
        foreach ($property in $item.PSObject.Properties) {
            # $prefixの値を元にドット表記の文字列を生成
            $propertyName = [System.String]::IsNullOrEmpty($prefix) ? $property.Name : "$prefix.$($property.Name)"
            if ([System.String]::IsNullOrEmpty($property.Value)) {
                # Propertyの値がNullまたは空の場合はスキップする
                continue    
            }
            elseif ($property.Value -is [System.Management.Automation.PSObject]) {
                # Propertyの値がオブジェクトの場合、再帰呼び出し
                $recursion = ConvertTo-DotNotation -item $property.Value -prefix $propertyName
                foreach ($key in $recursion.Keys) {
                    $output.Add($key, $recursion.$key)
                }
            }
            elseif ($property.Value -is [System.Array]) {
                # Propertyの値が配列の場合、再帰呼び出し
                for ($i = 0; $i -lt $property.Value.Count; $i++) {
                    $recursion = ConvertTo-DotNotation -item $property.Value[$i] -prefix "$propertyName[$i]"
                    foreach ($key in $recursion.Keys) {
                        $output.Add($key, $recursion.$key)
                    }
                }
            }
            elseif ($property.Value -is [System.Boolean]) {
                # Propertyの値が論理の場合、戻り値の変数に値をセット
                $output.Add($propertyName, $property.Value.ToString().ToLower())
            }
            else {
                # 上記のいずれにも合致しない(文字列/数字）場合、戻り値の変数に値をセット
                $output.Add($propertyName, $property.Value)
            }
        }
    }
    return $output
}

<# 
.SYNOPSIS
    リソースプロバイダを取得し、返却する。
.DESCRIPTION
    指定されたサブスクリプション配下のリソースプロバイダを取得し、それを返却します。
.PARAMETER subscriptionId
    AzureサブスクリプションのID
.OUTPUTS
    PSCustomObject[] : Get-ResourceProviderはリソースプロバイダの配列を返却します。
.EXAMPLE
    Get-ResourceProvider -subscriptionid $subscriptionId 
#>
function Get-ResourceProvider {
    param (
        [string]$subscriptionId
    )
    $parameters = @{
        Uri         = "https://management.azure.com/subscriptions/$($subscriptionId)/providers?api-version=2021-04-01"
        Method      = "Get"
        Headers     = $global:headers
        ContentType = "application/json;charset=utf-8"
    }
    $response = Invoke-RestMethod @parameters
    return @($response.value)
}

<#
.SYNOPSIS
    リソース一覧を取得し、返却する。
.DESCRIPTION
    指定されたサブスクリプション配下の指定された種類のリソース一覧を取得し、それを返却します。
.PARAMETER subscriptionId
    AzureサブスクリプションのID
.PARAMETER resourceType
.OUTPUTS
    PSCustomObject[] : Get-Resourcesはリソースの配列を返却します。
.EXAMPLE
    Get-Resources -subscriptionid $subscriptionId  -resourceTypes $resourceTypes
#>
function Get-Resources {
    param(
        [string]$subscriptionId,
        [string[]]$resourceTypes
    )
    $uriFilterString = "&`$filter=resourceType eq '{0}'" -f ($resourceTypes -join "' or resourceType eq '")
    $parameters = @{
        Uri         = "https://management.azure.com/subscriptions/$($subscriptionId)/resources?api-version=2021-04-01$uriFilterString"
        Method      = "Get"
        Headers     = $global:headers
        ContentType = "application/json;charset=utf-8"
    }
    $response = Invoke-RestMethod @parameters
    return @($response.value)
}

<#
.SYNOPSIS
    リソースのプロパティを取得し返却する。
.DESCRIPTION
    指定されたリソースのプロパティを、指定されたAPIバージョンで取得し、それを返却します。
.PARAMETER resourceId
    リソースID
.PARAMETER apiVersion
    リソースタイプのAPIバージョン
.OUTPUTS
    PSCustomObject: Get-ResourcePropertyはリソースを返却します
.EXAMPLE
    Get-ResourceProperty -resourceId $resourceId -apiVersion $apiVersion
#>
function Get-ResourceProperty {
    param (
        [string]$resourceId,
        [string]$apiVersion
    )
    $parameters = @{
        Uri         = "https://management.azure.com/$($resourceId)?api-version=$($apiVersion)"
        Method      = "Get"
        Headers     = $global:headers
        ContentType = "application/json;charset=utf-8"
    }
    $response = Invoke-RestMethod @parameters
    return $response
}

Export-ModuleMember -Function Get-LocalDateTime
Export-ModuleMember -Function Write-Log
Export-ModuleMember -Function Get-AuthorizationHeader
Export-ModuleMember -Function Compare-DotNotation
Export-ModuleMember -Function ConvertTo-DotNotation
Export-ModuleMember -Function Get-ResourceProvider
Export-ModuleMember -Function Get-Resources
Export-ModuleMember -Function Get-ResourceProperty