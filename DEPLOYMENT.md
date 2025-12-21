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

### 5.1 ステージング環境と本番環境

Mesh v2では、ステージング環境（stg）と本番環境（prod）を分離して管理します。

**ステージング環境へのデプロイ:**

```bash
# ステージング環境（デフォルト）
npx cdk deploy --context stage=stg

# または --context を省略（cdk.jsonのデフォルト値 "stg" が使用される）
npx cdk deploy
```

**本番環境へのデプロイ:**

```bash
# 本番環境
npx cdk deploy --context stage=prod
```

### 5.2 デプロイされるリソース名

| Stage | Stack名 | DynamoDB Table名 | AppSync API名 |
|-------|---------|------------------|---------------|
| stg | MeshV2Stack-stg | MeshV2Table-stg | MeshV2Api-stg |
| prod | MeshV2Stack | MeshV2Table | MeshV2Api |

### 5.3 リソースタグ

すべてのリソースには以下のタグが自動的に付与されます:

| タグキー | 値（stg） | 値（prod） |
|---------|----------|-----------|
| Project | MeshV2 | MeshV2 |
| Stage | stg | prod |
| Service | AppSync | AppSync |
| ManagedBy | CDK | CDK |
| ResourceType | GraphQLAPI / DynamoDB | GraphQLAPI / DynamoDB |

これらのタグは、AWS Cost Explorer でのコスト分析やリソースグルーピングに使用できます。

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

### 6.4 リソースタグの確認

デプロイされたリソースにタグが正しく付与されているか確認します。

**AppSync APIのタグ確認:**

```bash
# ステージング環境
API_ARN=$(aws appsync list-graphql-apis --query "graphqlApis[?name=='MeshV2Api-stg'].arn" --output text)
aws appsync list-tags-for-resource --resource-arn $API_ARN

# 本番環境
API_ARN=$(aws appsync list-graphql-apis --query "graphqlApis[?name=='MeshV2Api'].arn" --output text)
aws appsync list-tags-for-resource --resource-arn $API_ARN
```

期待される出力:
```json
{
    "tags": {
        "Project": "MeshV2",
        "Service": "AppSync",
        "Stage": "stg",
        "ResourceType": "GraphQLAPI",
        "ManagedBy": "CDK"
    }
}
```

**DynamoDB Tableのタグ確認:**

```bash
# ステージング環境
TABLE_ARN=$(aws dynamodb describe-table --table-name MeshV2Table-stg --query 'Table.TableArn' --output text)
aws dynamodb list-tags-of-resource --resource-arn $TABLE_ARN

# 本番環境
TABLE_ARN=$(aws dynamodb describe-table --table-name MeshV2Table --query 'Table.TableArn' --output text)
aws dynamodb list-tags-of-resource --resource-arn $TABLE_ARN
```

期待される出力:
```json
{
    "Tags": [
        {
            "Key": "Project",
            "Value": "MeshV2"
        },
        {
            "Key": "Stage",
            "Value": "stg"
        },
        {
            "Key": "Service",
            "Value": "AppSync"
        },
        {
            "Key": "ResourceType",
            "Value": "DynamoDB"
        },
        {
            "Key": "ManagedBy",
            "Value": "CDK"
        }
    ]
}
```

### 6.5 DynamoDB Tableの確認

```bash
# ステージング環境のテーブル詳細を確認
aws dynamodb describe-table --table-name MeshV2Table-stg

# 本番環境のテーブル詳細を確認
aws dynamodb describe-table --table-name MeshV2Table

# GSIの確認（オプション1: JSON形式で詳細表示 - 推奨）
# ステージング環境
aws dynamodb describe-table --table-name MeshV2Table-stg \
  --query 'Table.GlobalSecondaryIndexes[*].{IndexName:IndexName,KeySchema:KeySchema}' \
  --output json

# 本番環境
aws dynamodb describe-table --table-name MeshV2Table \
  --query 'Table.GlobalSecondaryIndexes[*].{IndexName:IndexName,KeySchema:KeySchema}' \
  --output json

# GSIの確認（オプション2: テーブル形式でインデックス名のみ）
# ステージング環境
aws dynamodb describe-table --table-name MeshV2Table-stg \
  --query 'Table.GlobalSecondaryIndexes[*].IndexName' \
  --output table

# 本番環境
aws dynamodb describe-table --table-name MeshV2Table \
  --query 'Table.GlobalSecondaryIndexes[*].IndexName' \
  --output table
```

期待される出力（オプション1: JSON形式）:
```json
[
  {
    "IndexName": "GroupIdIndex",
    "KeySchema": [
      {
        "AttributeName": "gsi_pk",
        "KeyType": "HASH"
      },
      {
        "AttributeName": "gsi_sk",
        "KeyType": "RANGE"
      }
    ]
  }
]
```

期待される出力（オプション2: テーブル形式）:
```
-----------------
|DescribeTable  |
+---------------+
|  GroupIdIndex |
+---------------+
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

## 9. AWS Resource Groups でのリソース管理

タグを使ってリソースをグルーピングし、一元管理できます。

### 9.1 リソースグループの作成

**ステージング環境のリソースグループ:**

```bash
aws resource-groups create-group \
  --name "MeshV2-stg" \
  --resource-query '{
    "Type": "TAG_FILTERS_1_0",
    "Query": "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"Project\",\"Values\":[\"MeshV2\"]},{\"Key\":\"Stage\",\"Values\":[\"stg\"]}]}"
  }' \
  --tags Project=MeshV2,Stage=stg
```

**本番環境のリソースグループ:**

```bash
aws resource-groups create-group \
  --name "MeshV2-prod" \
  --resource-query '{
    "Type": "TAG_FILTERS_1_0",
    "Query": "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"Project\",\"Values\":[\"MeshV2\"]},{\"Key\":\"Stage\",\"Values\":[\"prod\"]}]}"
  }' \
  --tags Project=MeshV2,Stage=prod
```

### 9.2 リソースグループの確認

```bash
# グループ一覧
aws resource-groups list-groups

# グループ内のリソース確認
aws resource-groups list-group-resources --group-name MeshV2-stg
```

### 9.3 コスト分析

AWS Cost Explorerでタグを使ったコスト分析が可能です。

**ステージング環境のコスト:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --filter '{
    "Tags": {
      "Key": "Stage",
      "Values": ["stg"]
    }
  }'
```

**リソースタイプ別コスト:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=TAG,Key=ResourceType \
  --filter '{
    "Tags": {
      "Key": "Project",
      "Values": ["MeshV2"]
    }
  }'
```

## 10. リソースの削除（必要な場合）

開発環境のリソースを削除する場合:

```bash
# ステージング環境のスタック削除
npx cdk destroy --context stage=stg

# 本番環境のスタック削除（慎重に）
npx cdk destroy --context stage=prod

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
