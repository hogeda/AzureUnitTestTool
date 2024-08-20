[string]$TimeDifference = "9:00"
[string[]]$TimeDiffHrsMin = "$($TimeDifference)".Split(':')
function Get-LocalDateTime {
    return (Get-Date).ToUniversalTime().AddHours($TimeDiffHrsMin[0]).AddMinutes($TimeDiffHrsMin[1])
}

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

function ConvertTo-DotProperty {
    <#
        Json(ハッシュテーブル)をドットプロパティ形式にして出力する。
        文字列"key:value"の配列を返却する
        その後keyとvalueに分割したいのであれば、正規表現「"key:value" -match "^(?<key>[^:]+)(?=:):(?<value>.+)$"」を用いて、$Matches.keyと$Matches.valueで取り出す
        -replace を使う際には"`${key}"のようにすれば名前付きキャプチャを指定できる
    #>
    param(
        [Object] $item,
        [String] $prefix
    )
    $output = @()
    if ($item -is [System.String]) {
        $propName = $prefix
        $output += "$propName`:$item"
    }
    else {
        foreach ($property in $item.PSObject.Properties) {
            $propName = [System.String]::IsNullOrEmpty($prefix) ? $property.Name : "$prefix.$($property.Name)"
            if ($property.Value -is [System.Management.Automation.PSObject] -or
                $property.Value -is [hashtable]) {
                $output += ConvertTo-DotProperty -item $property.Value -prefix $propName
            }
            elseif ($property.Value -is [System.Collections.IEnumerable] -and
                $property.Value -isnot [System.String]) {
                for ($i = 0; $i -lt $property.Value.Count; $i++) {
                    $output += ConvertTo-DotProperty -item $property.Value[$i] -prefix "$propName[$i]"
                }
            }
            else {
                $output += "$propName`:$($property.Value)"
            }
        }
    }
    return $output
}


function Compare-DotProperty {
    param(
        [String[]] $visible,
        [String] $dotPropertyKey
    )
    if ($dotPropertyKey -match "(?<=\[)\d+(?=\])") {
        return $visible -contains ($dotPropertyKey -replace "(?<=\[)\d+(?=\])", "")
    }
    else {
        return $visible -contains $dotPropertyKey
    }
}

Export-ModuleMember -Function Write-Log
Export-ModuleMember -Function Get-LocalDateTime
Export-ModuleMember -Function ConvertTo-DotProperty
Export-ModuleMember -Function Compare-DotProperty