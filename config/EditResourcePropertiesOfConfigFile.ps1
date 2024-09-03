using module '..\module\Common.psm1'
Add-Type -AssemblyName System.Windows.Forms

#region: variable
$configFilePath = "$PSScriptRoot\GetAzureResourceDotProperty.config.json"
$ErrorActionPreference = 'Continue'
$global:logfilePath = "$PSScriptRoot\{0}.log" -f (Get-LocalDateTime).ToString("yyyyMMddHHmmss")
$global:config = ""
$global:headers = ""
#endregion

#region: function
<#
.SYNOPSIS
    Resources Property変数の初期化
.DESCRIPTION
    引数で指定されたリソースプロバイダーの情報を元に、Resources Property変数を初期化する。
.PARAMETER resourceProviders
    リソースプロバイダーオブジェクトの配列
.OUTPUTS
    System.Collections.ArrayList: type,apiVersion,visibleの3つのキーを持ったDictionaryの配列
.EXAMPLE
    Initialize-ResourcesProperty -resourceProviders $resourceProviders
#>
function Initialize-ResourcesProperty {
    param(
        [object]$resourceProviders
    )
    $resourcesProperty = [System.Collections.ArrayList]::new()
    foreach ($resourceProvider in $resourceProviders) {
        $resourceProviderName = $resourceProvider.namespace
        foreach ($resourceType in $resourceProvider.resourceTypes) {
            $resourceTypeName = $resourceType.resourceType
            # リソースタイプのapiVersionsがnullの場合はスキップする
            if ([System.String]::IsNullOrEmpty($resourceType.apiVersions)) { continue }
            $resourceProperty = [ordered]@{
                type       = "{0}/{1}" -f $resourceProviderName, $resourceTypeName
                apiVersion = @($resourceType.apiVersions | Sort-Object -Descending)[0]
                visible    = [System.Collections.ArrayList]::new()
            }
            $resourcesProperty.Add($resourceProperty) | Out-Null
        }
    }
    return $resourcesProperty
}

<#
.SYNOPSIS
    WindowsFormでリソースプロバイダー、リソースタイプをユーザーに選択させて、resourcesProperty変数を更新する。
.DESCRIPTION
    引数で渡されたresourcesPropertyのtypeを元に、リソースプロバイダーをユーザーに選択させる。
    選択されたリソースプロバイダーが提供するリソースタイプをユーザーに選択させる。
    選択されたリソースタイプのみのresourcesPropertyを返却する。
.PARAMETER resourcesProperty
    コンフィグファイルのresourcesProperty部分の変数
.OUTPUTS
    System.Collections.ArrayList: type,apiVersion,visibleの3つのキーを持ったDictionaryの配列
.EXAMPLE
    Edit-ResourcesProperty -resourcesProperty $resourcesProperty
#>
function Edit-ResourcesProperty {
    param (
        [System.Collections.ArrayList]$resourcesProperty
    )
    $resourceProviderNames = $resourcesProperty.type -replace "^(?<provider>.+?)(?=\/)\/(?<type>.+)$", "`${provider}" | Sort-Object -Unique
    $selectedResourceProviderNames = Show-CheckListForm -items $resourceProviderNames -formText "リソースプロバイダーの選択"
    $resourceTypeNames = $resourcesProperty.type | Where-Object { $selectedResourceProviderNames -contains ($_ -replace "^(?<provider>.+?)(?=\/)\/(?<type>.+)$", "`${provider}") } | Sort-Object
    $selectedResourceTypeNames = Show-CheckListForm -items $resourceTypeNames -formText "リソースタイプの選択"
    return @($resourcesProperty | Where-Object { $selectedResourceTypeNames -contains $_.type })
}

<#
.SYNOPSIS
    指定されたリストをチェックボックス形式で表示し、選択された項目を返却する。
.DESCRIPTION
    Windows Formを用いて、指定されたアイテムをチェックボックス形式で表示します。
    フォームのタイトルについても、引数で指定してください。
.NOTES
    chatgptにて生成
.PARAMETER items
    リストの項目
.PARAMETER formText
    Windowsフォームのタイトル
.OUTPUTS
    string[]: Show-CheckListFormはユーザーが選択した項目のみを返却します。
.EXAMPLE
    Show-CheckListForm -items $item -formText $formText
#>
function Show-CheckListForm {
    param (
        [string[]]$items, # リストの項目
        [string]$formText    # フォームのタイトル
    )
    
    # 選択された項目を返すための変数をスクリプトスコープで定義
    $script:selectedItems = @()

    # ハッシュテーブルでチェック状態を管理
    $checkedStates = @{}

    # 初期化時に全アイテムのチェック状態をFalseで設定
    foreach ($item in $items) {
        $checkedStates[$item] = $false
    }

    # メインフォームの作成
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $formText
    $form.Size = New-Object System.Drawing.Size(500, 500)  # 横幅を大きく
    $form.StartPosition = "CenterScreen"

    # 検索テキストボックスの作成
    $searchTextBox = New-Object System.Windows.Forms.TextBox
    $searchTextBox.Size = New-Object System.Drawing.Size(460, 20)
    $searchTextBox.Location = New-Object System.Drawing.Point(10, 10)
    
    # CheckedListBoxの作成
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Size = New-Object System.Drawing.Size(460, 380)  # 横幅を大きく
    $checkedListBox.Location = New-Object System.Drawing.Point(10, 40)
    $checkedListBox.CheckOnClick = $true

    # 項目をCheckedListBoxに追加
    $checkedListBox.Items.AddRange($items)

    # チェックされた状態を復元
    $checkedListBox.Items | ForEach-Object { 
        if ($checkedStates[$_]) {
            $checkedListBox.SetItemChecked($checkedListBox.Items.IndexOf($_), $true)
        }
    }

    # 検索を行うスクリプトブロック
    $searchScript = {
        $searchTerm = $searchTextBox.Text.Trim()
        
        # 現在のチェック状態を保存
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedStates[$checkedListBox.Items[$i]] = $checkedListBox.GetItemChecked($i)
        }

        # 検索結果でリストを更新（前方一致）
        $filteredItems = $items | Where-Object { $_ -like "$searchTerm*" }

        # 検索結果が空でない場合のみAddRangeを呼び出す
        $checkedListBox.Items.Clear()
        if ($filteredItems) {
            $checkedListBox.Items.AddRange($filteredItems)
        }

        # チェック状態を復元
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            if ($checkedStates[$checkedListBox.Items[$i]]) {
                $checkedListBox.SetItemChecked($i, $true)
            }
        }
    }

    # テキストボックスに入力があるたびに動的に検索を実行
    $searchTextBox.Add_TextChanged({
            & $searchScript
        })

    # 確認ボタンの作成
    $confirmButton = New-Object System.Windows.Forms.Button
    $confirmButton.Text = "確認"
    $confirmButton.Location = New-Object System.Drawing.Point(200, 430)
    $confirmButton.Add_Click({
            # 最終的なチェック状態を保存
            for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                $checkedStates[$checkedListBox.Items[$i]] = $checkedListBox.GetItemChecked($i)
            }

            # チェックされた項目をリストアップして昇順ソート
            $checkedItems = $checkedStates.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key } | Sort-Object

            # チェックされた項目が存在する場合、新しいフォームで表示
            if ($checkedItems.Count -gt 0) {
                # 新しいフォームの作成
                $resultForm = New-Object System.Windows.Forms.Form
                $resultForm.Text = "選択された項目"
                $resultForm.Size = New-Object System.Drawing.Size(500, 400)  # 横幅を大きく
                $resultForm.StartPosition = "CenterScreen"

                # スクロール可能なTextBoxの作成
                $resultTextBox = New-Object System.Windows.Forms.TextBox
                $resultTextBox.Multiline = $true
                $resultTextBox.ScrollBars = "Vertical"
                $resultTextBox.ReadOnly = $true
                $resultTextBox.Size = New-Object System.Drawing.Size(460, 280)  # 横幅を大きく
                $resultTextBox.Location = New-Object System.Drawing.Point(10, 10)

                # チェックされた項目を1行ずつ表示
                $resultTextBox.Text = ($checkedItems -join [Environment]::NewLine)

                # OKボタンの作成
                $okButton = New-Object System.Windows.Forms.Button
                $okButton.Text = "OK"
                $okButton.Location = New-Object System.Drawing.Point(310, 320)
                $okButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
                $okButton.Add_Click({
                        $script:selectedItems = $checkedItems  # スクリプトスコープの変数に値を設定
                        $resultForm.Close()
                        $form.Close()
                    })

                # キャンセルボタンの作成
                $cancelButton = New-Object System.Windows.Forms.Button
                $cancelButton.Text = "キャンセル"
                $cancelButton.Location = New-Object System.Drawing.Point(390, 320)
                $cancelButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
                $cancelButton.Add_Click({
                        $resultForm.Close()
                    })

                # フォームにコントロールを追加
                $resultForm.Controls.Add($resultTextBox)
                $resultForm.Controls.Add($okButton)
                $resultForm.Controls.Add($cancelButton)

                # フォームを表示
                $resultForm.Add_Shown({ $resultForm.Activate() })
                [void]$resultForm.ShowDialog()
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("何も選択されていません。")
            }
        })

    # メインフォームにコントロールを追加
    $form.Controls.Add($searchTextBox)
    $form.Controls.Add($checkedListBox)
    $form.Controls.Add($confirmButton)

    # メインフォームを表示
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()

    # 選択された項目を返す
    return $script:selectedItems
}

<#
.SYNOPSIS
    resourcesProperty変数のvisibleプロパティの値を、実際に取得できたリソースの情報を元に設定します。
.DESCRIPTION
    実際のリソースが有しているプロパティの項目からvisibleリストを作成します。
    同じ種類のリソースだとしても、リソースによって有しているプロパティに差があります。
    全てのリソースのプロパティを列挙することで、抜け漏れないようにします。
    リソースが見当たらない場合には、そのリソース種類のvisible作成をスキップします。
.PARAMETER resourcesProperty
    コンフィグファイルのresourcesProperty部分の変数
.PARAMETER resources
    サブスクリプションに存在するリソースの配列
.OUTPUTS
    なし。引数で受け取ったresourcesPropertyの値を直接更新します。
.EXAMPLE
    Set-VisibleOfResourcesProperty -resourcesProperty $resourcesProperty -resources $resources
#>
function Set-VisibleOfResourcesProperty {
    param (
        [System.Collections.ArrayList]$resourcesProperty,
        [object[]]$resources
    )
    foreach ($resourceProperty in $resourcesProperty) {
        $resourceIds = ($resources | Where-Object { $_.type -eq $resourceProperty.type }).id
        if ([System.String]::IsNullOrEmpty($resourceIds)) {
            Write-Log -Warn -Message "`$resourceIdsが空です。「$($resourceProperty.type)」のリソースがサブスクリプションに存在しないため、このリソースタイプのvisible作成は断念します。"
            continue
        }
        $dotNotations = [System.Collections.ArrayList]::new()
        foreach ($resourceId in $resourceIds) {
            $detailedResource = Get-ResourceProperty -resourceId $resourceId -apiVersion $resourceProperty.apiVersion
            $dotNotation = ConvertTo-DotNotation -inputObject $detailedResource -prefix "" -returnAsOrderedDictionary
            $dotNotations.Add($dotNotation) | Out-Null
        }
        $visible = @($dotNotations.Keys -replace "(?<=\[)\d+(?=\])", "" | Select-Object -Unique)
        $visible = Optimize-DotNotationKey -item $visible -prefix ""
        $resourceProperty.visible = $visible
    }
}
#endregion

#region: Check PSVersion
if($PSVersionTable.PSVersion.Major -lt 7){
    Write-Log -Err -Message ("""This script requires Powershell version 7 or higher. Your PSVersion is {0}""" -f $PSVersionTable.PSVersion.ToString())
}
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

#region: new(edit) config file
Write-Log -Message "[Info]start to new(edit) config file"
$resourceProviders = Get-ResourceProvider -subscriptionId $global:config.subscriptionId | Where-Object { $_.registrationState -eq "Registered" }
$resourcesProperty = @(Initialize-ResourcesProperty -resourceProviders $resourceProviders) # 登録済みのリソースプロバイダの情報でまずは初期化する
$resourcesProperty = @(Edit-ResourcesProperty -resourcesProperty $resourcesProperty) # WindowsFormで必要なリソースプロバイダー/リソースタイプを選択させる
$resources = Get-Resources -subscriptionId $global:config.subscriptionId -resourceType @($resourcesProperty.type)
Set-VisibleOfResourcesProperty -resourcesProperty $resourcesProperty -resources $resources
$global:config.resourcesProperty = $resourcesProperty
$global:config | ConvertTo-Json -Depth 100 | Out-File -FilePath $configFilePath -Force -Encoding utf8
Write-Log -Message "[Info]finish to to new(edit) config file"
#endregion

Write-Log -Message "[Info]finish to main logic"
#endregion