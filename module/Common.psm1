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
    if ($dotNotationKey -match "(?<=\[)\d+(?=\])") {
        return $visible -contains ($dotNotationKey -replace "(?<=\[)\d+(?=\])", "")
    }
    else {
        return $visible -contains $dotNotationKey
    }
}

<#
.SYNOPSIS
    JSON文字列またはPowershellオブジェクトをドット記法(順序付きディクショナリ)に変換します。
.DESCRIPTION
    JSON文字列を指定する場合はstring型である必要があります。JSONファイルをGet-Contentする際には、-Rawスイッチを利用してください。
    Powershellオブジェクトを指定する場合は特に指定はありません。JSONファイルをGet-Contentする際には、パイプラインでConvertFrom-Jsonを利用してください。
    $prefixパラメータは再帰処理のために用いますが、これに文字列を指定して実行することで、ドット記法のプロパティ名に任意のプレフィックスを付与することが可能です。
    出力結果からnullまたは空白文字列を除外したい場合には、-ignoreNullOrEmptyスイッチを利用してください。
.PARAMETER json
    string: 必須(inputObjectでも可)、JSON文字列を指定します
.PARAMETER inputObject
    object: 必須(jsonでも可)、オブジェクトを指定します
.PARAMETER prefix
    string: 任意、ドット記法プロパティにプレフィックスを指定します
.PARAMETER ignoreNullorEmpty
    switch: 任意、解析時にnull値を除外します
.OUTPUTS
    System.Collections.Specialized.OrderedDictionary
.EXAMPLE
    ConvertTo-DotNotation -json $json [-prefix $prefix] [-ignoreNullOrEmpty]
    ConvertTo-DotNotation -inputObject $jsonObj [-prefix $prefix] [-ignoreNullOrEmpty]
#>
function ConvertTo-DotNotation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "ByJsonString")]
        [string]$json,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "ByObject")]
        [object]$inputObject,

        [Parameter()]
        [string]$prefix = "",

        [Parameter()]
        [switch]$ignoreNullorEmpty
    )

    # 初期化
    if ($json) {
        $item = $json | ConvertFrom-Json
    }
    else {
        $item = $inputObject
    }
    $output = [ordered]::new()

    # メイン処理
    if (
        $item -is [char] -or $item -is [string] -or 
        $item -is [short] -or $item -is [int] -or $item -is [long] -or $item -is [bigint] -or
        $item -is [byte] -or $item -is [sbyte] -or
        $item -is [ushort] -or $item -is [uint] -or $item -is [ulong] -or 
        $item -is [single] -or $item -is [double] -or
        $item -is [decimal] -or
        $item -is [bool]
    ) {
        # $itemがkey,value形式でなく値(文字列、数字、論理値)の場合
        $propertyName = $prefix
        if ($item -is [bool]) {
            # 論理値の場合は小文字にする
            $output.Add($propertyName, $item.ToString().ToLower())
        }
        else {
            $output.Add($propertyName, $item)
        }
    }
    elseif ([System.String]::IsNullOrEmpty($item) -and !$ignoreNullorEmpty) {
        # $itemがnullの場合
        $propertyName = $prefix
        $output.Add($propertyName, $null)
    }
    else {
        # $itemがkey,value形式であるなら、$itemが有するPropertyの種類に応じて処理を分ける
        foreach ($property in $item.PSObject.Properties) {
            # $prefixの値を元にドット表記の文字列を生成
            if ([System.String]::IsNullOrEmpty($prefix)) {
                $propertyName = $property.Name
            }
            else {
                $propertyName = "$prefix.$($property.Name)"
            }

            if ($property.Value -is [System.Management.Automation.PSObject]) {
                # オブジェクトの場合、再帰呼び出し
                $recursion = ConvertTo-DotNotation -inputObject $property.Value -prefix $propertyName -ignoreNullorEmpty:$ignoreNullorEmpty
                foreach ($key in $recursion.Keys) {
                    $output.Add($key, $recursion.$key)
                }
            }
            elseif ($property.Value -is [System.Array]) {
                # 配列の場合、再帰呼び出し
                for ($i = 0; $i -lt $property.Value.Count; $i++) {
                    $recursion = ConvertTo-DotNotation -inputObject $property.Value[$i] -prefix "$propertyName[$i]" -ignoreNullorEmpty:$ignoreNullorEmpty
                    foreach ($key in $recursion.Keys) {
                        $output.Add($key, $recursion.$key)
                    }
                }
            }
            elseif ($property.Value -is [char] -or $property.Value -is [string]) {
                # 文字列の場合、再帰なし
                if ([System.String]::IsNullOrEmpty($property.Value) -and !$ignoreNullorEmpty) { continue }
                $output.Add($propertyName, $property.Value)
            }
            elseif (
                $property.Value -is [short] -or $property.Value -is [int] -or $property.Value -is [long] -or $property.Value -is [bigint] -or
                $property.Value -is [byte] -or $property.Value -is [sbyte] -or
                $property.Value -is [ushort] -or $property.Value -is [uint] -or $property.Value -is [ulong] -or 
                $property.Value -is [single] -or $property.Value -is [double] -or
                $property.Value -is [decimal]
            ) {
                # 数字の場合、再帰無し
                $output.Add($propertyName, $property.Value)
            }
            elseif ($property.Value -is [bool]) {
                # 論理値の場合、再帰無し
                $output.Add($propertyName, $property.Value.ToString().ToLower())
            }
            elseif ([System.String]::IsNullOrEmpty($property.Value) -and !$ignoreNullorEmpty ) {
                $output.Add($propertyName, $null)
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
        Uri         = "https://management.azure.com$($resourceId)?api-version=$($apiVersion)"
        Method      = "Get"
        Headers     = $global:headers
        ContentType = "application/json;charset=utf-8"
    }
    $response = Invoke-RestMethod @parameters
    return $response
}

<#
.SYNOPSIS
    dotNotationの一覧を元の順序を維持したまま、不規則な配置を修正します。
.DESCRIPTION
    Sort-Objectを用いてしまうと、name,id,type,properties... といった順序を維持することができません。
    全てのリソースのプロパティをドット表記で一覧化し、それを重複排除するということを前段で実施しています。
    そのため、一覧化した際の状態に準じてプロパティのドット表記が非整列であるため、これを整列します。
    1. 指定されたドット記法のプレフィックスを抜き出し、重複排除したものを並び替えの順序として定義します。
    2. 並び替えの順序に従って（プレフィックスに合致する要素を）要素を整列させます。
        a. プレフィックスに合致する要素が1つだけの場合は単にそのデータを配置します。
        b. プレフィックスに合致する要素が複数存在する場合は、それはドット記法が更にネストされていることを示します。
             再帰処理にてそのネストされた要素の並び替えを行い、それらを配置します。
    必要に応じてコンフィグファイルを直接開いて順番を修正してください。
.PARAMETER item
    並び替え対象のドット記法のキーの配列
.PARAMETER prefix
    再帰処理を行う際のプレフィックス文字列
.OUTPUTS
    string[]: Optimize-DotNotationKeyは引数の$itemを整列して返します。
.EXAMPLE
    Optimize-DotNotationKey -item $item -prefix $prefix
#>
function Optimize-DotNotationKey {
    param (
        [string[]]$item,
        [string]$prefix
    )
    $output = @()
    $ordered = $item -replace "\..+$", "" | Select-Object -Unique # ドット記法のプレフィックスを抜き出し、重複を排除
    foreach ($key in $ordered) {
        # $matchString = "^{0}(`$|\.)" -f ($key -replace "\[\]", "\[\]")
        $matchString = "^{0}(`$|\.)" -f ($key -replace "(?=\[)|(?=\])","\")
        $subArray = $item -match $matchString
        if ($subArray.Count -eq 1) {
            # 部分配列の要素が1つの時、それ以上分割する必要はないので値をセット
            $output += $subArray -replace "^", "$prefix"
        }
        else {
            # 部分配列の要素が複数の時、部分配列の各要素から先頭の$keyを削除したものを新たに定義し、それを用いて再帰処理
            $subArray = $subArray -replace "$($matchString)", ""
            $output += Optimize-DotNotationKey -item $subArray -prefix "$($prefix)$($key)."
        }
    }
    return $output
}

Export-ModuleMember -Function Get-LocalDateTime
Export-ModuleMember -Function Write-Log
Export-ModuleMember -Function Get-AuthorizationHeader
Export-ModuleMember -Function Compare-DotNotation
Export-ModuleMember -Function ConvertTo-DotNotation
Export-ModuleMember -Function Get-ResourceProvider
Export-ModuleMember -Function Get-Resources
Export-ModuleMember -Function Get-ResourceProperty
Export-ModuleMember -Function Optimize-DotNotationKey