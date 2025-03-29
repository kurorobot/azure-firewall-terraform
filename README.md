# Azure Firewall を使用したセキュアな RDP 環境

このプロジェクトでは、Terraform を使用して Azure Firewall を経由したセキュアな RDP 接続環境を構築します。ローカル PC から特定の VM に RDP 接続するための最小構成を提供します。

## アーキテクチャ概要

アーキテクチャは以下のコンポーネントで構成されています：

- **Azure Firewall**: すべての受信・送信トラフィックを制御
- **仮想ネットワーク**: 2 つのサブネット（Firewall 用と VM 用）を含む
- **Windows VM**: RDP 接続の対象となるサーバー
- **ネットワークセキュリティグループ(NSG)**: VM サブネットのセキュリティを強化
- **ルートテーブル**: VM からのトラフィックを Firewall に転送

## 前提条件

- Azure サブスクリプション
- Azure CLI
- Terraform 1.0.0 以上

## ディレクトリ構成

azure-firewall-rdp/
├── main.tf # メインのリソース定義
├── variables.tf # 変数定義
├── outputs.tf # 出力値の定義
└── terraform.tfvars # 変数の実際の値（ローカル IP など）

## セットアップ手順

### 1. 環境準備

1-1. Azure CLI のインストール（まだの場合）
https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli

macOS: brew update && brew install azure-cli

1-2. Azure にログイン
az login

# 現在のサブスクリプション ID を確認（Terraform で使用する場合）

az account show --query id -o tsv

### 2. terraform.tfvars の設定

terraform.tfvars ファイルを作成し、以下の変数を設定します：

- local_ip: ローカル PC の IP アドレス
- admin_password: 仮想マシンの管理者パスワード

### 3. リソースの作成

terraform init
terraform plan
terraform apply
確認メッセージが表示されたら、`yes`と入力してデプロイを開始します。

### 4. RDP 接続

デプロイが完了すると、以下の出力が表示されます：

- `firewall_public_ip`: Azure Firewall のパブリック IP アドレス
- `vm_private_ip`: VM のプライベート IP アドレス

RDP 接続には以下の情報を使用します：

- **ホスト**: `firewall_public_ip`の値
- **ユーザー名**: `azureadmin`（デフォルト）
- **パスワード**: `terraform.tfvars`で設定したパスワード

### 5. リソースの削除

使用が終わったら、以下のコマンドでリソースを削除します：
terraform destroy

## 注意事項

- このセットアップは、テスト目的でのみ使用してください。
- 本番環境では、より安全な認証方法を検討する必要があります。

## リソースの説明

### 1. ネットワーク構成

- **仮想ネットワーク (10.0.0.0/16)**: すべてのリソースを含む
  - **AzureFirewallSubnet (10.0.1.0/24)**: Firewall 専用サブネット
  - **VM Subnet (10.0.2.0/24)**: VM が配置されるサブネット

### 2. Azure Firewall

- **ネットワークルール**: ローカル IP から VM サブネットへの RDP トラフィック（TCP/3389）を許可
- **DNAT ルール**: ローカル IP から Firewall のパブリック IP への RDP トラフィックを VM のプライベート IP に転送

### 3. ルーティング

- **ルートテーブル**: VM サブネットからのすべてのトラフィックを Firewall に転送するデフォルトルート

### 4. セキュリティ

- **NSG**: VM サブネットに適用され、ローカル IP からの RDP トラフィックのみを許可

## 注意点

- Azure Firewall はコストが高いリソースです。テスト後は`terraform destroy`で削除することをお勧めします
- 実際の運用環境では、パスワードではなく SSH キーを使用するなど、より強固なセキュリティ設定を検討してください
- `terraform.tfvars`ファイルは機密情報を含むため、Git などのバージョン管理システムにコミットしないよう注意してください

## トラブルシューティング

### RDP 接続ができない場合

1. ローカル IP アドレスが正しく設定されているか確認
2. Firewall のデプロイが完了しているか確認（10〜15 分かかることがあります）
3. DNAT ルールとネットワークルールの両方が正しく設定されているか確認
4. NSG が RDP トラフィックを許可しているか確認

### Terraform のロックエラー

状態ファイルのロックに関するエラーが発生した場合：
terraform destroy -lock=false

## 参考リソース

- [Azure Firewall のドキュメント](https://docs.microsoft.com/ja-jp/azure/firewall/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
