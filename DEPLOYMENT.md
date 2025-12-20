# Mesh v2 デプロイメントガイド

このドキュメントでは、Mesh v2インフラストラクチャのデプロイと動作確認の手順を説明します。

## 前提条件

- Node.js 18+ がインストール済み
- AWS CLI がインストール・設定済み
- AWS CDK CLI がインストール済み (`npm install -g aws-cdk`)
- AWSアカウントの認証情報が設定済み

## 1. AWS認証情報の確認

デプロイ前に、AWS CLIが正しく設定されているか確認します。

```bash
# AWS認証情報の確認
aws sts get-caller-identity
```

出力例:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### 認証情報の設定（未設定の場合）

```bash
# AWS認証情報の設定
aws configure

# 入力項目:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region name (例: ap-northeast-1)
# - Default output format (例: json)
```

## 2. 依存関係のインストール

```bash
cd /Users/kouji/work/smalruby/smalruby3-develop/infra/mesh-v2

# npm依存関係のインストール
npm install

# TypeScriptのビルド
npm run build
```

## 3. CDK Bootstrap（初回のみ）

AWS環境でCDKを初めて使用する場合、bootstrapが必要です。

```bash
# 現在のAWSアカウント・リージョンでbootstrap
cdk bootstrap

# 特定のアカウント・リージョンを指定する場合
# cdk bootstrap aws://ACCOUNT-NUMBER/REGION
```

Bootstrap完了後の出力例:
```
 ✅  Environment aws://123456789012/ap-northeast-1 bootstrapped.
```

### Bootstrap済みか確認する方法

```bash
# CloudFormationスタックの確認
aws cloudformation describe-stacks --stack-name CDKToolkit
```

スタックが存在すればbootstrap済みです。

## 4. デプロイ前の確認

CloudFormationテンプレートを生成して、デプロイ内容を確認します。

```bash
# CloudFormationテンプレートの生成
npx cdk synth

# デプロイ差分の確認
npx cdk diff
```

## 5. デプロイ実行

```bash
# スタックのデプロイ
npx cdk deploy

# 確認プロンプトが表示されるので、y を入力
```

デプロイには数分かかります。進行状況がリアルタイムで表示されます。

### デプロイ成功時の出力

デプロイが完了すると、以下のような出力が表示されます:

```
 ✅  MeshV2Stack

✨  Deployment time: 120.5s

Outputs:
MeshV2Stack.GraphQLApiEndpoint = https://xxxxxxxxxxxxxxxxxx.appsync-api.ap-northeast-1.amazonaws.com/graphql
MeshV2Stack.GraphQLApiId = xxxxxxxxxxxxxxxxxxxx
MeshV2Stack.GraphQLApiKey = da2-xxxxxxxxxxxxxxxxxxxxxxxxxx
MeshV2Stack.TableArn = arn:aws:dynamodb:ap-northeast-1:123456789012:table/MeshV2Table
MeshV2Stack.TableName = MeshV2Table

Stack ARN:
arn:aws:cloudformation:ap-northeast-1:123456789012:stack/MeshV2Stack/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**重要**: `GraphQLApiEndpoint` と `GraphQLApiKey` の値を控えてください。動作確認で使用します。

## 6. 動作確認

### 6.1 AWS Management Consoleでの確認

#### AppSync API の確認

1. AWS Management Console にログイン
2. **AppSync** サービスに移動
3. **MeshV2Api** を選択
4. **Schema** タブでGraphQLスキーマを確認

#### DynamoDB Table の確認

1. AWS Management Console で **DynamoDB** サービスに移動
2. **Tables** から **MeshV2Table** を選択
3. **Indexes** タブで **GroupIdIndex** GSIを確認

### 6.2 GraphQL API のテスト

AppSync Consoleの **Queries** タブで、以下のクエリをテストできます。

#### テスト1: グループの作成 (createGroup)

```graphql
mutation CreateGroup {
  createGroup(
    name: "テストグループ1"
    hostId: "host-001"
    domain: "test-domain"
  ) {
    id
    domain
    fullId
    name
    hostId
    createdAt
  }
}
```

**注意**: 現時点ではResolverが未実装のため、このMutationは失敗します。これは正常です。Phase 2でResolverを実装します。

#### テスト2: グループ一覧の取得 (listGroupsByDomain)

```graphql
query ListGroups {
  listGroupsByDomain(domain: "test-domain") {
    id
    domain
    fullId
    name
    hostId
    createdAt
  }
}
```

#### テスト3: スキーマのイントロスペクション

GraphQL APIが正しく動作しているか確認:

```graphql
query IntrospectionQuery {
  __schema {
    queryType {
      name
    }
    mutationType {
      name
    }
    subscriptionType {
      name
    }
  }
}
```

期待される出力:
```json
{
  "data": {
    "__schema": {
      "queryType": {
        "name": "Query"
      },
      "mutationType": {
        "name": "Mutation"
      },
      "subscriptionType": {
        "name": "Subscription"
      }
    }
  }
}
```

### 6.3 CLIからのテスト

`curl` コマンドでAPIをテストすることもできます。

```bash
# 環境変数の設定
export APPSYNC_ENDPOINT="<GraphQLApiEndpoint の値>"
export API_KEY="<GraphQLApiKey の値>"

# イントロスペクションクエリの実行
curl -X POST "$APPSYNC_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "query": "query { __schema { queryType { name } mutationType { name } subscriptionType { name } } }"
  }' | jq
```

### 6.4 DynamoDB Tableの確認

```bash
# テーブルの詳細を確認
aws dynamodb describe-table --table-name MeshV2Table

# GSIの確認
aws dynamodb describe-table --table-name MeshV2Table \
  --query 'Table.GlobalSecondaryIndexes[*].[IndexName,KeySchema]' \
  --output table
```

期待される出力:
```
----------------------------------------------------
|              DescribeTable                       |
+--------------------------------------------------+
||                  GroupIdIndex                  ||
||------------------------------------------------||
|||               KeySchema                      |||
||+----------------------+-----------------------+||
|||  AttributeName       |  KeyType             |||
||+----------------------+-----------------------+||
|||  gsi_pk              |  HASH                |||
|||  gsi_sk              |  RANGE               |||
||+----------------------+-----------------------+||
```

## 7. CloudWatch Logsの確認

AppSync APIのログはCloudWatch Logsに出力されます。

```bash
# ロググループ一覧の確認
aws logs describe-log-groups --log-group-name-prefix /aws/appsync/apis

# 最新のログストリームを確認
LOG_GROUP_NAME=$(aws logs describe-log-groups \
  --log-group-name-prefix /aws/appsync/apis \
  --query 'logGroups[0].logGroupName' \
  --output text)

echo "Log Group: $LOG_GROUP_NAME"

# 最新ログの取得
aws logs tail "$LOG_GROUP_NAME" --follow
```

## 8. X-Ray トレースの確認

X-Rayトレーシングが有効になっているため、リクエストのトレース情報を確認できます。

1. AWS Management Console で **X-Ray** サービスに移動
2. **Service map** でMeshV2Apiを確認
3. **Traces** でリクエストの詳細を確認

## 9. リソースの削除（必要な場合）

開発環境のリソースを削除する場合:

```bash
# スタックの削除
npx cdk destroy

# 確認プロンプトで y を入力
```

**警告**: この操作でDynamoDBテーブルとデータが完全に削除されます（`RemovalPolicy: DESTROY`設定のため）。

## トラブルシューティング

### デプロイが失敗する場合

#### 1. 認証エラー

```
Error: Need to perform AWS calls for account XXX, but no credentials found
```

**解決策**: AWS認証情報を設定してください。
```bash
aws configure
```

#### 2. Bootstrapエラー

```
Error: This stack uses assets, so the toolkit stack must be deployed to the environment
```

**解決策**: CDK Bootstrapを実行してください。
```bash
cdk bootstrap
```

#### 3. リソース名の競合

```
Error: MeshV2Table already exists
```

**解決策**: 既存のスタックを削除するか、テーブル名を変更してください。

### APIが応答しない場合

1. CloudWatch Logsでエラーメッセージを確認
2. API Keyが正しいか確認
3. エンドポイントURLが正しいか確認
4. IAM権限が正しく設定されているか確認

## 次のステップ

Phase 1のデプロイが完了したら、Phase 2でAppSync Resolverを実装します:

- JavaScript Resolverの実装
- DynamoDB CRUD操作の実装
- Domain自動取得ロジックの実装
- Subscriptionの動作確認

詳細は Issue #449 を参照してください。

## 参考リンク

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [AWS AppSync Developer Guide](https://docs.aws.amazon.com/appsync/)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)
