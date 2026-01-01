# Mesh v2 API Reference

このドキュメントは、Mesh v2 GraphQL API の完全なリファレンスです。

## 概要

Mesh v2 は AWS AppSync を使用した GraphQL API を提供します。

- **プロトコル**: GraphQL over HTTPS (Queries/Mutations), WebSocket (Subscriptions)
- **認証**: API Key
- **エンドポイント**: デプロイ後に CloudFormation の Outputs で確認
- **言語**: GraphQL Schema Definition Language (SDL)

## GraphQL Schema 概要

### 主要な型定義

#### Group

```graphql
type Group {
  id: ID!           # group_id のみ
  domain: String!   # グローバル IP またはカスタム文字列（最大 256 文字）
  fullId: String!   # {id}@{domain}
  name: String!
  hostId: ID!       # 作成者ノード ID
  createdAt: AWSDateTime!
}
```

#### Node

```graphql
type Node {
  nodeId: ID!
  groupId: ID!
  domain: String!
  joinedAt: AWSDateTime!
}
```

#### SensorData

```graphql
type SensorData {
  key: String!
  value: String!
}
```

#### Event

```graphql
type Event {
  name: String!
  firedByNodeId: ID!
  payload: AWSJSON
  timestamp: AWSDateTime!
}
```

#### NodeStatus

```graphql
type NodeStatus {
  nodeId: ID!
  groupId: ID!
  domain: String!
  data: [SensorData!]!
  timestamp: AWSDateTime!
}
```

#### BatchEvent

```graphql
type BatchEvent {
  events: [Event!]!
  firedByNodeId: ID!
  groupId: ID!
  domain: String!
  timestamp: AWSDateTime!
}
```

#### GroupDissolvePayload

```graphql
type GroupDissolvePayload {
  groupId: ID!
  domain: String!
  message: String!
}
```

## Queries

### listGroupsByDomain

ドメイン内のすべてのグループを一覧表示します。

```graphql
query ListGroupsByDomain($domain: String!) {
  listGroupsByDomain(domain: $domain) {
    id
    domain
    fullId
    name
    hostId
    createdAt
  }
}
```

### getGroup

グループ ID とドメインでグループを取得します。

```graphql
query GetGroup($groupId: ID!, $domain: String!) {
  getGroup(groupId: $groupId, domain: $domain) {
    id
    domain
    fullId
    name
    hostId
    createdAt
  }
}
```

## Mutations

### createGroup

新しいグループを作成します（冪等性あり）。

```graphql
mutation CreateGroup($name: String!, $hostId: ID!, $domain: String!) {
  createGroup(name: $name, hostId: $hostId, domain: $domain) {
    id
    domain
    fullId
    name
    hostId
    createdAt
  }
}
```

**冪等性**: 同じ `hostId` + `domain` で呼び出すと、既存のグループを返します。

### joinGroup

ノードがグループに参加します。

```graphql
mutation JoinGroup($groupId: ID!, $nodeId: ID!, $domain: String!) {
  joinGroup(groupId: $groupId, nodeId: $nodeId, domain: $domain) {
    nodeId
    groupId
    domain
    joinedAt
  }
}
```

### reportDataByNode

ノードがセンサーデータを報告します（`onDataUpdateInGroup` subscription をトリガー）。

```graphql
mutation ReportDataByNode(
  $nodeId: ID!
  $groupId: ID!
  $domain: String!
  $data: [SensorDataInput!]!
) {
  reportDataByNode(
    nodeId: $nodeId
    groupId: $groupId
    domain: $domain
    data: $data
  ) {
    nodeId
    groupId
    domain
    data {
      key
      value
    }
    timestamp
  }
}
```

### fireEventsByNode

ノードが複数のイベントを一度に送信します（`onBatchEventInGroup` subscription をトリガー）。

```graphql
mutation FireEventsByNode(
  $nodeId: ID!
  $groupId: ID!
  $domain: String!
  $events: [EventInput!]!
) {
  fireEventsByNode(
    nodeId: $nodeId
    groupId: $groupId
    domain: $domain
    events: $events
  ) {
    events {
      name
      firedByNodeId
      payload
      timestamp
    }
    firedByNodeId
    groupId
    domain
    timestamp
  }
}
```

### dissolveGroup

グループを解散します（`onGroupDissolve` subscription をトリガー）。

```graphql
mutation DissolveGroup($groupId: ID!, $domain: String!) {
  dissolveGroup(groupId: $groupId, domain: $domain) {
    groupId
    domain
    message
  }
}
```

**注意**: 以前の `leaveGroup` mutation は削除され、`dissolveGroup` mutation に置き換えられました。

## Subscriptions

Mesh v2 は AWS AppSync GraphQL Subscriptions over WebSocket を使用したリアルタイム通知をサポートしています。

### onDataUpdateInGroup

**目的**: リアルタイムでグループ内のノードデータ更新を購読

**トリガー**: `reportDataByNode` mutation

**パラメータ**:
- `groupId: ID!` - 購読するグループ ID
- `domain: String!` - グループのドメイン

**戻り値**: `NodeStatus!`
```graphql
{
  nodeId: ID!
  groupId: ID!
  domain: String!
  data: [SensorData!]!
  timestamp: AWSDateTime!
}
```

**使用例**:
```graphql
subscription {
  onDataUpdateInGroup(groupId: "group-123", domain: "example.com") {
    nodeId
    groupId
    data {
      key
      value
    }
    timestamp
  }
}
```

---

### onBatchEventInGroup

**目的**: 複数イベントを一度に送信（1回の Subscription を発火）

**トリガー**: `fireEventsByNode` mutation

**パラメータ**:
- `groupId: ID!` - 購読するグループ ID
- `domain: String!` - グループのドメイン

**戻り値**: `BatchEvent!`
```graphql
{
  events: [Event!]!
  firedByNodeId: ID!
  groupId: ID!
  domain: String!
  timestamp: AWSDateTime!
}
```

**使用例**:
```graphql
subscription {
  onBatchEventInGroup(groupId: "group-123", domain: "example.com") {
    events {
      name
      firedByNodeId
      payload
      timestamp
    }
  }
}
```

---

### onGroupDissolve

**目的**: リアルタイムでグループ解散を購読

**トリガー**: `dissolveGroup` mutation

**パラメータ**:
- `groupId: ID!` - 購読するグループ ID
- `domain: String!` - グループのドメイン

**戻り値**: `GroupDissolvePayload!`
```graphql
{
  groupId: ID!
  domain: String!
  message: String!
}
```

**使用例**:
```graphql
subscription {
  onGroupDissolve(groupId: "group-123", domain: "example.com") {
    groupId
    domain
    message
  }
}
```

---

### Subscription のフィルタリング動作

すべての subscription は `groupId` と `domain` でフィルタリングされます:
- `groupId: "A"` を購読しているクライアントは、`groupId: "B"` の更新を受信**しません**
- このフィルタリングは、subscription パラメータを使用して AppSync が自動的に処理します

---

### Subscription のテスト

#### 自動テスト

統合テストで以下を検証:
- ✅ GraphQL schema に Subscription type が含まれている
- ✅ @aws_subscribe ディレクティブが正しく定義されている
- ✅ Mutations (reportDataByNode, fireEventsByNode, dissolveGroup) が正しく動作する
- ✅ 複数のグループが適切なフィルタリングで共存できる
- ✅ onGroupDissolve subscription が正しくトリガーされる

テストを実行:
```bash
export APPSYNC_ENDPOINT=$(aws cloudformation describe-stacks --stack-name MeshV2Stack-stg --query 'Stacks[0].Outputs[?OutputKey==`GraphQLApiEndpoint`].OutputValue' --output text)
export APPSYNC_API_KEY=$(aws cloudformation describe-stacks --stack-name MeshV2Stack-stg --query 'Stacks[0].Outputs[?OutputKey==`GraphQLApiKey`].OutputValue' --output text)

bundle exec rspec spec/requests/subscriptions_spec.rb
```

#### 手動 WebSocket テスト

実際の WebSocket 接続を使用した手動テストには、`wscat` または GraphQL Playground を使用します:

1. **wscat をインストール**:
```bash
npm install -g wscat
```

2. **WebSocket URL を取得**:
```bash
API_URL='https://your-appsync-api.appsync-api.region.amazonaws.com/graphql'
WS_URL=$(echo $API_URL | sed 's/https:/wss:/g' | sed 's/graphql$/graphql\/connect/g')
```

3. **接続して購読**: GraphQL Playground または wscat を適切な AppSync WebSocket プロトコルで使用

4. **Mutations をトリガー**: 別のターミナルで、GraphQL API を使用して mutations を実行

---

### Subscription のパフォーマンス考慮事項

#### 接続制限
- AppSync は、アカウントごと、リージョンごとに最大 100,000 の同時 WebSocket 接続をサポート
- 各 subscription は 1 つの接続としてカウント

#### メッセージ配信
- メッセージはほぼリアルタイムで購読者に配信されます（通常 < 100ms）
- AppSync は最低 1 回の配信を保証
- クライアントは重複メッセージに対して冪等性を実装する必要があります

#### コスト最適化
- Subscriptions はメッセージ送信ごとに課金されます
- 未使用の接続を閉じてコストを削減
- 不要なメッセージを最小限にするために特定のフィルター（groupId、domain）を使用

---

### Subscription のトラブルシューティング

#### 接続の問題
1. API Key が有効で期限切れでないことを確認
2. WebSocket URL の形式を確認: `wss://xxx.appsync-api.region.amazonaws.com/graphql/connect`
3. 適切な WebSocket ヘッダーを確認（AppSync ドキュメント参照）

#### 更新が届かない
1. subscription パラメータが mutation パラメータと一致することを確認（groupId、domain）
2. mutation が正常に完了したことを確認
3. クライアントがまだ接続されていることを確認（WebSocket がタイムアウトしていない）

#### ローカルでのテスト
- AppSync subscriptions は実際の WebSocket 接続が必要
- 単体テストでは完全にテストできない
- 統合テストまたは wscat/GraphQL Playground を使用した手動テストを使用

---

## エラーハンドリング

### GraphQL エラー型

Mesh V2 バックエンドは以下の GraphQL エラー型を返します。

| エラー型 | 説明 | クライアントアクション | 定義場所 |
| :--- | :--- | :--- | :--- |
| `GroupNotFound` | グループが存在しない、期限切れ、またはホストのハートビートがタイムアウトした | **即座に切断** | `js/functions/checkGroupExists.js` |
| `Unauthorized` | 認可されていないノードが操作を試みた（例：非ホストがグループのハートビートを更新しようとした） | **即座に切断** | `js/functions/renewHeartbeatFunction.js` |
| `NodeNotFound` | 指定されたノード（クライアント）がグループに存在しない | **即座に切断** | `js/functions/updateNodeTTL.js` |
| `ValidationError` | 提供されたパラメータが検証に失敗した（例：ドメイン文字列が長すぎる） | エラーをログに記録して続行（切断**しない**） | 各種リゾルバー |

### クライアント実装の詳細

クライアント（`scratch-vm`）は、`MeshV2Service` にこれらのエラーを処理する `shouldDisconnectOnError(error)` ヘルパーメソッドを実装しています。

#### mesh-service.js の切断ロジック

```javascript
const DISCONNECT_ERROR_TYPES = new Set([
    'GroupNotFound',
    'Unauthorized',
    'NodeNotFound'
]);

shouldDisconnectOnError (error) {
    if (!error) return false;

    // 主要なチェック: GraphQL errorType（最も信頼性が高い）
    if (error.graphQLErrors && error.graphQLErrors.length > 0) {
        const errorType = error.graphQLErrors[0].errorType;
        if (DISCONNECT_ERROR_TYPES.has(errorType)) {
            return true;
        }
    }

    // フォールバック: メッセージ文字列をチェック（後方互換性）
    if (error.message) {
        const message = error.message.toLowerCase();
        if (message.includes('not found') ||
            message.includes('expired') ||
            message.includes('unauthorized')) {
            return true;
        }
    }

    return false;
}
```

### 新しいエラー型の追加

クライアントに切断を要求する新しいエラー型をバックエンドに追加する場合:

1. `util.error(message, errorType)` を使用して適切な AppSync 関数でエラーを定義
2. このドキュメントに新しいエラー型を追加
3. `gui/scratch-vm/src/extensions/scratch3_mesh_v2/mesh-service.js` の `DISCONNECT_ERROR_TYPES` セットを更新

---

## 認証・認可

### API Key 認証

現在、Mesh v2 は API Key 認証を使用しています:

```bash
# API Key を取得
aws cloudformation describe-stacks --stack-name MeshV2Stack-stg \
  --query 'Stacks[0].Outputs[?OutputKey==`GraphQLApiKey`].OutputValue' \
  --output text
```

**使用方法**:

```bash
curl -X POST $APPSYNC_ENDPOINT \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { listGroupsByDomain(domain: \"example.com\") { id name } }"
  }'
```

### 将来の拡張

- IAM 認証のサポート予定
- Cognito ユーザープール認証のサポート予定

---

## レート制限

AWS AppSync のデフォルトのレート制限が適用されます:

- リクエスト制限: アカウントごと、リージョンごとに秒間 1,000 リクエスト
- Subscription 接続制限: アカウントごと、リージョンごとに 100,000 接続

詳細は [AWS AppSync のクォータ](https://docs.aws.amazon.com/appsync/latest/devguide/quotas.html) を参照してください。

---

## 関連ファイル

- **Schema**: `graphql/schema.graphql`
- **Subscription テスト**: `spec/requests/subscriptions_spec.rb`
- **Subscription ヘルパー**: `spec/support/appsync_subscription_helper.rb`
- **CDK Stack**: `lib/mesh-v2-stack.ts`

---

## 関連ドキュメント

- [開発ガイド](development.md) - ローカル開発とテスト
- [デプロイ手順](deployment.md) - 初回デプロイから運用まで
- [README.md](../README.md) - プロジェクト概要

---

## 参考資料

- [AWS AppSync Subscriptions](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-real-time-data.html)
- [GraphQL Subscriptions Specification](https://spec.graphql.org/October2021/#sec-Subscription)
- [AppSync @aws_subscribe Directive](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-directives.html#aws-appsync-subscribe)
- [AWS AppSync Quotas](https://docs.aws.amazon.com/appsync/latest/devguide/quotas.html)

---

**Last Updated**: 2026-01-01
**Phase**: 3 - Documentation Consolidation
**Status**: ✅ Subscriptions と Error Types を統合（完全な API リファレンスは Phase 4 で追加予定）
