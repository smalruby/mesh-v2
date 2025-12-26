// renewHeartbeat Mutation Resolver
// ホストの生存確認を行い、TTLを延長する

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { groupId, domain, hostId } = ctx.args;
  const nowEpoch = Math.floor(util.time.nowEpochMilliSeconds() / 1000);
  const ttl = nowEpoch + 300; // 5分延長

  return {
    operation: 'UpdateItem',
    key: util.dynamodb.toMapValues({
      pk: `DOMAIN#${domain}`,
      sk: `GROUP#${groupId}#METADATA`
    }),
    update: {
      expression: 'SET heartbeatAt = :now, ttl = :ttl',
      expressionValues: util.dynamodb.toMapValues({
        ':now': nowEpoch,
        ':ttl': ttl
      })
    },
    condition: {
      expression: 'hostId = :hostId',
      expressionValues: util.dynamodb.toMapValues({
        ':hostId': hostId
      })
    }
  };
}

export function response(ctx) {
  if (ctx.error) {
    if (ctx.error.type === 'DynamoDB:ConditionalCheckFailedException') {
      util.error('Only the host can renew the heartbeat or group not found', 'Unauthorized');
    }
    util.error(ctx.error.message, ctx.error.type);
  }

  return {
    groupId: ctx.result.id,
    domain: ctx.result.domain,
    expiresAt: ctx.result.expiresAt
  };
}
