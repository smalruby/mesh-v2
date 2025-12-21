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

### 2. onEventInGroup

**Purpose**: リアルタイムでグループ内のイベント発火を購読

**Trigger**: `fireEventByNode` mutation

**Parameters**:
- `groupId: ID!` - 購読するグループID
- `domain: String!` - グループのドメイン

**Returns**: `Event!`
```graphql
{
  name: String!
  firedByNodeId: ID!
  groupId: ID!
  domain: String!
  payload: String
  timestamp: AWSDateTime!
}
```

**Usage Example**:
```graphql
subscription {
  onEventInGroup(groupId: "group-123", domain: "example.com") {
    name
    firedByNodeId
    payload
    timestamp
  }
}
```

---

### 3. onGroupDissolve (未実装)

**Status**: ⚠️ Currently not implemented due to type mismatch

**Issue**:
- `leaveGroup` mutation returns `Node?` (nullable)
- `onGroupDissolve` subscription expects `GroupDissolvePayload!` (non-null)
- AppSync requires subscription return types to match mutation return types

**Future Implementation Options**:
1. Create separate `dissolveGroup` mutation that explicitly returns `GroupDissolvePayload!`
2. Change `leaveGroup` return type to union type `Node | GroupDissolvePayload`
3. Use AppSync Pipeline Resolvers to transform the response

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
- ✅ Mutations (reportDataByNode, fireEventByNode) work correctly
- ✅ Multiple groups can coexist with proper filtering

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

  onEventInGroup(groupId: ID!, domain: String!): Event!
    @aws_subscribe(mutations: ["fireEventByNode"])
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

**Last Updated**: 2025-12-21
**Phase**: 2-4 - Subscription Implementation
**Status**: ✅ Implemented (2/3 subscriptions)
