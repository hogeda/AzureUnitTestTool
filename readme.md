# Azureリソース設定値抜き出しツール

## フォルダ構成

<pre>
.
├── GetAzureResourceDotProperty.ps1
├── readme.md
├── config/
│   ├── EditResourcePropertiesOfConfigFile.ps1
│   └── GetAzureResourceDotProperty.config.json
└── module/
    └── Common.psm1
</pre>

## 概要

- サービスプリンシパルがAzureリソースの設定値を取得し、ドットプロパティ形式でCSVファイルに設定値の情報を出力します。
- Configファイルには、サービスプリンシパルの認証情報、設定値を抜き出す対象のサブスクリプション、設定値を抜き出す対象のリソースタイプを指摘してください

## 前提条件

- サービスプリンシパルをMicrosoft Entra IDに作成してください
- そのサービスプリンシパルに対してサブスクリプションのReader権限を割り当ててください
- サービスプリンシパルの認証方式はシークレットにのみ対応しています

## 使い方

### コンフィグファイルの作成

- 以下を参考にしてコンフィグファイルを作成します。次の値を設定してください。
    resourcePropertiesは空のままで構いません。
  - authentication.tenantId
  - authentication.client_id
  - authentication.client_secret
  - subscriptionId

```Json
{
  "authentication": {
    "tenantId": "テナントID",
    "client_id": "サービスプリンシパルのクライアントID",
    "client_secret": "サービスプリンシパルのシークレット"
  },
  "subscriptionId": "サブスクリプションID",
  "resourceProperties": []
}
```

- EditResourceProeprtiesOfConfigFile.ps1を実行します
  - リソースプロバイダーの選択画面が起動するので、対象とするリソースプロバイダーを選択してください
  - 続けてリソースタイプの選択画面が起動するので、対象とするリソースタイプを選択してください
  - 実行が完了するとConfigファイルのresourcePropertiesに値がセットされています。必要に応じてapiVersionやvisibleを更新してください。※詳細は後述します
  - visibleの削除についてはコメントアウト(//)でも大丈夫ですが、有効なJSON形式となるように、配列の末尾の項目であれば「,」を削除することを忘れないでください

### ツールの実行

コンフィグファイルの準備ができたら、ツール実行の前提条件が整いました。

- GetAzureResourceDotProperty.ps1ファイルを実行します。
  - 実行が完了すると同フォルダにCSVファイルが出力されます。

## コンフィグファイルについて

resourcePropertiesについて説明します。
この項目には取得対象となるリソースタイプの情報を列挙します。
| 項目       | 説明                                                                                              |
| ---------- | ------------------------------------------------------------------------------------------------- |
| type       | リソースタイプを指定します。RESOURCEPROVIDER/RESOURCETYPE形式で記載してください。                   |
| apiVersion | 設定値取得のREST APIで用いるAPIバージョンを指定します。デフォルトでは最新のAPIバージョンが選択されています。                                             |
| visible    | CSV出力時に含まれるドットプロパティの項目を指定します。配列の場合、インデックスは削除します。 |

visibleについて補足します。たとえば仮想マシンリソースの設定値をREST APIでGETした時の結果は以下のようになりますが、作成しているパラメータシートの項目と比べて余計な情報が存在すると思います。（etagやtimecreated、provisioningState等）
不要な項目であればエクスポートする際に除外しますので、出力すべきプロパティをvisibleに記載してください。

```JSON
{
  "name": "vmname",
  "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RESOURCEGROUP/providers/Microsoft.Compute/virtualMachines/vmname",
  "type": "Microsoft.Compute/virtualMachines",
  "location": "japaneast",
  "properties": {
    "hardwareProfile": {
      "vmSize": "Standard_B2s"
    },
    "provisioningState": "Succeeded", //デプロイが成功したかはパラメータ管理しないので、単体試験不要
    "vmId": "11111111-1111-1111-1111-111111111111",
    "additionalCapabilities": {
      "hibernationEnabled": false
    },
    "storageProfile": {
      "imageReference": {
        "publisher": "MicrosoftWindowsServer",
        "offer": "WindowsServer",
        "sku": "2022-datacenter",
        "version": "latest",
        "exactVersion": "20348.2529.240619"
      },
      "osDisk": {
        "osType": "Windows",
        "name": "vmname_OsDisk",
        "createOption": "FromImage",
        "caching": "ReadWrite",
        "managedDisk": {
          "storageAccountType": "Standard_LRS",
          "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RESOURCEGROUP/providers/Microsoft.Compute/disks/vmname_OsDisk"
        },
        "deleteOption": "Delete",
        "diskSizeGB": 127
      },
      "dataDisks": []
    },
    "osProfile": {
      "computerName": "vmname",
      "adminUsername": "admin",
      "windowsConfiguration": {
        "provisionVMAgent": true,
        "enableAutomaticUpdates": true,
        "patchSettings": {
          "patchMode": "AutomaticByOS",
          "assessmentMode": "ImageDefault",
          "enableHotpatching": false
        }
      },
      "secrets": [],
      "allowExtensionOperations": true,
      "requireGuestProvisionSignal": true
    },
    "networkProfile": {
      "networkInterfaces": [
        {
          "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RESOURCEGROUP/providers/Microsoft.Network/networkInterfaces/nicname",
          "properties": {
            "deleteOption": "Detach"
          }
        }
      ]
    },
    "diagnosticsProfile": {
      "bootDiagnostics": {
        "enabled": true
      }
    },
    "timeCreated": "2024-07-03T04:33:58.9307087+00:00" // いつ作成されたかについても管理する必要なし
  },
  "etag": "\"93\"", // リソースの更新にまつわるetagも管理する必要なし
  "resources": [ // 拡張機能リソースについては個別で管理するので、VMの試験として不要
    {
      "name": "MDE.Windows",
      "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RESOURCEGROUP/providers/Microsoft.Compute/virtualMachines/vmname/extensions/MDE.Windows",
      "type": "Microsoft.Compute/virtualMachines/extensions",
      "location": "japaneast",
      "properties": {
        "autoUpgradeMinorVersion": true,
        "forceUpdateTag": "22222222-2222-2222-2222-222222222222",
        "provisioningState": "Succeeded",
        "publisher": "Microsoft.Azure.AzureDefenderForServers",
        "type": "MDE.Windows",
        "typeHandlerVersion": "1.0",
        "settings": {
          "azureResourceId": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RESOURCEGROUP/providers/Microsoft.Compute/virtualMachines/vmname",
          "forceReOnboarding": false,
          "vNextEnabled": true,
          "autoUpdate": true
        }
      }
    }
  ]
}
```

## その後について

出力されるCSVファイルはid,dotProperty,valueという構成です。
このCSVファイルをExcelでインポートしてください。
A列にリソースのドットプロパティを記載し、1行目にリソースIDを入力します。
例えばリソースIDとドットプロパティをキーとして、XLOOKUP関数で値を拾ってくれば完成です。
見栄えよくするのであれば、ドットプロパティの隣のセルにTEXTSPLIT()を用いて「.」で区切るようにしましょう。
条件付き書式で直前の(一つ上のセル)と値が同じであれば、文字色をセル背景色と同じにすれば、それっぽくなります。
※Excel上でのデータの取り扱いはもっといい方法があると思います。データ量多いので、例で示しているような配列式は推奨しません。

| ドットプロパティ(仮想マシン)                      | リソースAのID                                                  |
| ------------------------------------------------- | -------------------------------------------------------------- |
| name                                              | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A1),Sheet2!$C:$C) |
| type                                              | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A2),Sheet2!$C:$C) |
| location                                          | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A3),Sheet2!$C:$C) |
| properties.hardwareProfile.vmsize                 | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A4),Sheet2!$C:$C) |
| properties.storageProfile.osDisk.osType           | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A5),Sheet2!$C:$C) |
| properties.osProfile.computerName                 | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A6),Sheet2!$C:$C) |
| properties.osProfile.adminUserName                | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A7),Sheet2!$C:$C) |
| properties.networkProfile.networkInterfaces[0].id | =XLOOKUP(1,(Sheet2!$A:$A=B$1)*(Sheet2!$B:$B=$A8),Sheet2!$C:$C) |

![](.\etc\readme_fig1.png)
