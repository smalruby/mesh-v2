# Mesh v2 Subscriptions Implementation

## Overview

Mesh v2 supports real-time notifications using AWS AppSync GraphQL Subscriptions over WebSocket.

## Implemented Subscriptions

### 1. onDataUpdateInGroup

**Purpose**: リアルタイムでグループ内のノードデータ更新を購読

**Trigger**: `reportDataByNode` mutation

**Parameters**:
- `groupId: ID!` - 購読するグループID
- `domain: String!` - グループのドメイン

**Returns**: `NodeStatus!`
```graphql
{
  nodeId: ID!
  groupId: ID!
  domain: String!
  data: [SensorData!]!
  timestamp: AWSDateTime!
}
```

**Usage Example**:
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

### 2. onBatchEventInGroup

**Purpose**: 複数イベントを一度に送信（1回のSubscriptionを発火）

**Trigger**: `fireEventsByNode` mutation

**Parameters**:
- `groupId: ID!` - 購読するグループID
- `domain: String!` - グループのドメイン

**Returns**: `BatchEvent!`
```graphql
{
  events: [Event!]!
  firedByNodeId: ID!
  groupId: ID!
  domain: String!
  timestamp: AWSDateTime!
}
```

**Usage Example**:
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

### 3. onGroupDissolve

**Purpose**: リアルタイムでグループ解散を購読

**Trigger**: `dissolveGroup` mutation

**Parameters**:
- `groupId: ID!` - 購読するグループID
- `domain: String!` - グループのドメイン

**Returns**: `GroupDissolvePayload!`
```graphql
{
  groupId: ID!
  domain: String!
  message: String!
}
```

**Usage Example**:
```graphql
subscription {
  onGroupDissolve(groupId: "group-123", domain: "example.com") {
    groupId
    domain
    message
  }
}
```

**Note**:
- 以前の `leaveGroup` mutation は削除され、`dissolveGroup` mutation に置き換えられました
- `dissolveGroup` は明示的に `GroupDissolvePayload!` を返すため、型の不一致問題が解決されました

---

## Filtering Behavior

All subscriptions filter by `groupId` and `domain`:
- Clients subscribing to `groupId: "A"` will NOT receive updates for `groupId: "B"`
- This filtering is handled automatically by AppSync using the subscription parameters

---

## Testing

### Automated Tests

Integration tests verify:
- ✅ GraphQL schema contains Subscription type
- ✅ @aws_subscribe directives are correctly defined
- ✅ Mutations (reportDataByNode, fireEventsByNode, dissolveGroup) work correctly
- ✅ Multiple groups can coexist with proper filtering
- ✅ onGroupDissolve subscription triggers correctly

Run tests:
```bash
export APPSYNC_ENDPOINT=$(aws cloudformation describe-stacks --stack-name MeshV2Stack-stg --query 'Stacks[0].Outputs[?OutputKey==`GraphQLApiEndpoint`].OutputValue' --output text)
export APPSYNC_API_KEY=$(aws cloudformation describe-stacks --stack-name MeshV2Stack-stg --query 'Stacks[0].Outputs[?OutputKey==`GraphQLApiKey`].OutputValue' --output text)

bundle exec rspec spec/requests/subscriptions_spec.rb
```

### Manual WebSocket Testing

For manual testing with real WebSocket connections, use `wscat` or GraphQL Playground:

#### 1. Install wscat
```bash
npm install -g wscat
```

#### 2. Get WebSocket URL
```bash
API_URL='https://your-appsync-api.appsync-api.region.amazonaws.com/graphql'
WS_URL=$(echo $API_URL | sed 's/https:/wss:/g' | sed 's/graphql$/graphql\/connect/g')
```

#### 3. Connect and Subscribe
Use GraphQL Playground or wscat with proper AppSync WebSocket protocol

#### 4. Trigger Mutations
In another terminal, execute mutations using GraphQL API:
```bash
# Example: Report data to trigger onDataUpdateInGroup
curl -X POST $API_URL \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { reportDataByNode(...) { ... } }"
  }'
```

---

## Implementation Details

### Schema Definition
Location: `graphql/schema.graphql`

```graphql
type Subscription {
  onDataUpdateInGroup(groupId: ID!, domain: String!): NodeStatus!
    @aws_subscribe(mutations: ["reportDataByNode"])

  onBatchEventInGroup(groupId: ID!, domain: String!): BatchEvent!
    @aws_subscribe(mutations: ["fireEventsByNode"])
}
```

### AWS Resources
- **Service**: AWS AppSync (managed WebSocket infrastructure)
- **Protocol**: GraphQL subscriptions over WebSocket
- **Authentication**: API Key
- **Filtering**: Automatic by AppSync based on subscription parameters

### No Additional Resolvers Required
AppSync handles subscription logic automatically when using `@aws_subscribe` directive:
1. Client subscribes with parameters (groupId, domain)
2. Mutation is executed
3. AppSync automatically notifies matching subscribers
4. Filtering by parameters happens server-side

---

## Performance Considerations

### Connection Limits
- AppSync supports up to 100,000 concurrent WebSocket connections per account per region
- Each subscription counts as one connection

### Message Delivery
- Messages are delivered to subscribers in near real-time (< 100ms typical)
- AppSync guarantees at-least-once delivery
- Clients should implement idempotency for duplicate messages

### Cost Optimization
- Subscriptions are billed per message sent
- Close unused connections to reduce costs
- Use specific filters (groupId, domain) to minimize unnecessary messages

---

## Troubleshooting

### Connection Issues
1. Verify API Key is valid and not expired
2. Check WebSocket URL format: `wss://xxx.appsync-api.region.amazonaws.com/graphql/connect`
3. Ensure proper WebSocket headers (see AppSync documentation)

### Missing Updates
1. Verify subscription parameters match mutation parameters (groupId, domain)
2. Check that mutation completed successfully
3. Confirm client is still connected (WebSocket didn't timeout)

### Testing Locally
- AppSync subscriptions require real WebSocket connections
- Cannot be fully tested with unit tests
- Use integration tests or manual testing with wscat/GraphQL Playground

---

## Related Files

- **Schema**: `graphql/schema.graphql`
- **Tests**: `spec/requests/subscriptions_spec.rb`
- **Helper**: `spec/support/appsync_subscription_helper.rb`
- **CDK Stack**: `lib/mesh-v2-stack.ts`

---

## References

- [AWS AppSync Subscriptions](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-real-time-data.html)
- [GraphQL Subscriptions Specification](https://spec.graphql.org/October2021/#sec-Subscription)
- [AppSync @aws_subscribe Directive](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-directives.html#aws-appsync-subscribe)

---

**Last Updated**: 2025-12-31
**Phase**: 2-4 - Subscription Implementation
**Status**: ✅ Fully Implemented (onDataUpdate, onBatchEvent, onGroupDissolve)
