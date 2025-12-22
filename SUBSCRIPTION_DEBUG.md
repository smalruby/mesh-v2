# Subscription Debug Guide

## 問題

別デバイスのsubscriptionにsensor dataの変更が反応しない。

## 調査結果

### ✅ 確認済み（正常）

1. **GraphQLスキーマの設定**
   ```graphql
   type Subscription {
     onDataUpdateInGroup(groupId: ID!, domain: String!): NodeStatus
       @aws_subscribe(mutations: ["reportDataByNode"])
   }
   ```
   - `@aws_subscribe` directive が正しく設定されている
   - mutation名 `reportDataByNode` が一致している

2. **NodeStatus型の定義**
   ```graphql
   type NodeStatus {
     nodeId: ID!
     groupId: ID!    # ✓ subscription filtering に必要
     domain: String! # ✓ subscription filtering に必要
     data: [SensorData!]!
     timestamp: AWSDateTime!
   }
   ```
   - `groupId` と `domain` フィールドが含まれている（filtering用）

3. **Mutation Resolver (reportDataByNode)**
   - `js/resolvers/Mutation.reportDataByNode.js`
   - DynamoDBへの書き込みが正常に動作
   - `groupId` と `domain` を含むNodeStatusを返している

4. **AppSync Logging**
   - CloudWatch Logsで確認
   - `reportDataByNode` mutationが正常に実行されている
   - エラーログなし

5. **Subscription Query**
   - `mesh-client.js` のsubscription queryが正しい
   - `groupId` と `domain` を変数として渡している
   - 結果セットに `groupId` と `domain` を含めている

### ❓ 未確認（要デバッグ）

1. **Subscription接続の持続性**
   - WebSocket接続がタイムアウトしていないか
   - Amplifyのsubscription reconnect動作

2. **AppSyncのsubscription publish**
   - CloudWatch Logsにsubscription publishログが出力されているか
   - Filteringが正しく動作しているか

3. **ブラウザ側の受信**
   - `console.log('Subscription data received:')` が出力されているか
   - Network tabでWebSocket通信が確認できるか

## デバッグ手順

### Method 1: デバッグツールを使用

1. **デバッグツールを開く**
   ```bash
   cd examples/javascript-client
   npm start
   # Open http://localhost:3000/debug-subscription.html
   ```

2. **グループIDを準備**
   - メインプロトタイプ (http://localhost:3000) でグループを作成
   - グループIDをコピー

3. **デバッグツールで確認**
   - Group IDを入力
   - "1. Subscribe to onDataUpdateInGroup" をクリック
   - "2. Send Sensor Data" をクリック
   - ログに "SUBSCRIPTION DATA RECEIVED!" が表示されるか確認

### Method 2: ブラウザ2窓テスト

1. **Window 1: ホスト**
   ```
   http://localhost:3000?mesh=test-domain
   ```
   - グループ作成
   - ブラウザDevTools → Console を開く

2. **Window 2: メンバー**
   ```
   http://localhost:3000?mesh=test-domain
   ```
   - 同じグループに参加
   - ブラウザDevTools → Console を開く
   - ブラウザDevTools → Network タブで "WebSocket" フィルタを確認

3. **Window 1でセンサーデータ送信**
   - Temperatureスライダーを動かす
   - Console に "Sensor data sent:" が表示される

4. **Window 2で受信確認**
   - Console に "Subscription data received:" が表示されるか確認
   - Network tab で WebSocket メッセージを確認

### Method 3: CloudWatch Logs監視

```bash
# AppSyncログをリアルタイム監視
aws logs tail /aws/appsync/apis/2kw5fyno4bhjbc47mvu3rxytye --follow
```

**確認ポイント:**
1. Subscription接続ログ
2. reportDataByNode実行ログ
3. Subscription publishログ（これが重要！）

### Method 4: 統合テスト

```bash
cd /Users/kouji/work/smalruby/smalruby3-develop/infra/mesh-v2

# Subscription関連テスト実行
export APPSYNC_ENDPOINT=https://rb6mjlr72rhudiztdmfvoyctbq.appsync-api.ap-northeast-1.amazonaws.com/graphql
export APPSYNC_API_KEY=da2-kp6w6skjfjgpxb7ufwt25zophm

bundle exec rspec spec/requests/subscription_realtime_spec.rb --format documentation
```

## 予想される問題と解決策

### 問題1: WebSocket接続のタイムアウト

**症状:** Subscriptionを確立した数分後にmutationを実行しても反応しない

**原因:** AppSync WebSocket接続のデフォルトタイムアウト

**解決策:**
- Amplifyの reconnect設定を確認
- Keep-aliveメカニズムの実装

### 問題2: Subscription Filteringの不一致

**症状:** Mutationは成功するがsubscriptionに届かない

**原因:**
- subscription変数の `groupId`/`domain` とmutation結果の値が一致していない
- 大文字小文字の違い
- 余分な空白

**デバッグ:**
```javascript
// mesh-client.js の subscribeToDataUpdates に追加
console.log('Subscribing with variables:', { groupId, domain });

// app.js の sendSensorData に追加
console.log('Sending data to:', {
  groupId: state.currentGroup.id,
  domain: state.currentGroup.domain
});
```

### 問題3: AppSync @aws_subscribe の設定ミス

**症状:** Subscriptionが一切反応しない

**確認:**
```bash
# スキーマを確認
cat graphql/schema.graphql | grep -A 3 "onDataUpdateInGroup"

# 期待される出力:
# onDataUpdateInGroup(groupId: ID!, domain: String!): NodeStatus
#   @aws_subscribe(mutations: ["reportDataByNode"])
```

### 問題4: Amplifyのバージョン互換性

**症状:** Subscription接続はできるが、データが届かない

**確認:**
```bash
cd examples/javascript-client
npm list aws-amplify
```

**解決策:** AWS Amplify v6を使用（現在使用中）

## 次のステップ

1. **デバッグツール (`debug-subscription.html`) を使用して動作確認**
   - Subscriptionが正しく確立されるか
   - Mutationがsubscriptionをトリガーするか

2. **CloudWatch Logsでsubscription publish確認**
   - AppSyncがsubscriptionにpublishしているか
   - Filteringが正しく動作しているか

3. **必要に応じてコード修正**
   - Logging追加
   - Reconnect処理追加
   - Error handling改善

## 参考リンク

- [AWS AppSync Subscriptions](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-real-time-data.html)
- [AWS Amplify Subscriptions](https://docs.amplify.aws/javascript/build-a-backend/graphqlapi/subscribe-data/)
- [@aws_subscribe Directive](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-directives.html#aws-subscribe)

---

**Last Updated:** 2025-12-22
