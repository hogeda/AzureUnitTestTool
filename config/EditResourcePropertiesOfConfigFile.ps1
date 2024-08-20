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
#endregion

#region: Main
Write-Log -Message "[Info]start main logic"

# Read Config File
Write-Log -Message "[Info]start to read the config file"
$global:config = Get-Content -Path $configFilePath -Encoding utf8 | ConvertFrom-Json -AsHashtable
Write-Log -Message "[Info]finish to read the config file"

# Get Bearer token and Set headers
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

# コンフィグファイルの作成(修正)
Write-Log -Message "[Info]start to new(edit) config file"
# リソースプロバイダーの Getリクエスト
$parameter = @{
    Uri         = "https://management.azure.com/subscriptions/$($global:config.subscriptionId)/providers?api-version=2021-04-01"
    Method      = "Get"
    Headers     = $global:headers
    ContentType = "application/json;charset=utf-8"
}
$response = Invoke-RestMethod @parameter

# 登録済みのリソースプロバイダーのみを対象とする
$registeredResourceProviderObjects = $response.value | Where-Object { $_.registrationState -eq "Registered" }

# 取り扱いやすいようにデータを加工する
$resourceProperties = [ordered]@{resourceProperties = [System.Collections.ArrayList]::new() }
foreach ($registeredResourceProviderObject in $registeredResourceProviderObjects) {
    $resourceProviderName = $registeredResourceProviderObject.namespace
    foreach ($resourceType in $registeredResourceProviderObject.resourceTypes) {
        $resourceTypeName = $resourceType.resourceType
        # リソースタイプのapiVersionsがnullの場合はスキップする
        if ([System.String]::IsNullOrEmpty($resourceType.apiVersions)) { continue }
        $resourceProperty = [ordered]@{
            type       = "{0}/{1}" -f $resourceProviderName, $resourceTypeName
            apiVersion = ($resourceType.apiVersions | Sort-Object -Descending)[0]
            visible    = [System.Collections.ArrayList]::new()
        }
        $resourceProperties.resourceProperties.Add($resourceProperty) | Out-Null
    }
}

# Windowsフォームを使って、対象とするリソースプロバイダー、リソースタイプをユーザーに選択させる
$resourceProviderNames = $resourceProperties.resourceProperties.type -replace "^(?<provider>.+?)(?=\/)\/(?<type>.+)$", "`${provider}" | Sort-Object -Unique
$checkedResourceProviderNames = Show-CheckListForm -items $resourceProviderNames -formText "リソースプロバイダーの選択"
$resourceTypeNames = $resourceProperties.resourceProperties.type | Where-Object { $checkedResourceProviderNames -contains ($_ -replace "^(?<provider>.+?)(?=\/)\/(?<type>.+)$", "`${provider}") } | Sort-Object
$checkedResourceTypeNames = Show-CheckListForm -items $resourceTypeNames -formText "リソースタイプの選択"
$checkedResourceProperties = $resourceProperties.resourceProperties | Where-Object { $checkedResourceTypeNames -contains $_.type }

# 対象のリソースタイプのリソースをAzure環境から取得し、ドットプロパティを作成する
## 対象のリソースタイプのIDを取得する
$uriFilterString = "&`$filter=resourceType eq '{0}'" -f ($checkedResourceProperties.type -join "' or resourceType eq '")
$parameter = @{
    Uri         = "https://management.azure.com/subscriptions/$($global:config.subscriptionId)/resources?api-version=2021-04-01$uriFilterString"
    Method      = "Get"
    Headers     = $global:headers
    ContentType = "application/json;charset=utf-8"
}
$response = Invoke-RestMethod @parameter
foreach ($checkedResourceProperty in $checkedResourceProperties) {
    $sampleResource = $response.value | Where-Object { $_.type -eq $checkedResourceProperty.type } | Select-Object -First 1
    if ([System.String]::IsNullOrEmpty($sampleResource)) {
        Write-Log -Warn -Message "`$samplreResourceが空です。「$($checkedResourceProperty.type)」のリソースがサブスクリプションに存在しないため、このリソース種類のvisible作成は断念します"
        continue
    }
    $parameter = @{
        Uri         = "https://management.azure.com{0}?api-version={1}" -f $sampleResource.id, $checkedResourceProperty.apiVersion
        Method      = "Get"
        Headers     = $global:headers
        ContentType = "application/json;charset=utf-8"
    }
    $getResourceResponse = Invoke-RestMethod @parameter
    $dotProperty = ConvertTo-DotProperty -item $getResourceResponse -prefix "" # ドットプロパティへ変換
    $keyOfDotProperty = $dotProperty -replace "^(?<key>[^:]+)(?=:):(?<value>.+)$", "`${key}" # ドットプロパティからキーだけ取り出す
    $keyOfDotProperty = $keyOfDotProperty -replace "(?<=\[)\d+(?=\])", "" | Select-Object -Unique # さらに配列のインデックスを削除して重複排除する
    $checkedResourceProperty.visible = $keyOfDotProperty
}
## Configファイルの該当箇所を更新して処理終了
$global:config.resourceProperties = $checkedResourceProperties
$global:config | ConvertTo-Json -Depth 100 | Out-File -FilePath $configFilePath -Force -Encoding utf8
Write-Log -Message "[Info]finish to to new(edit) config file"