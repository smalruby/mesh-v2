// Mutation.recordEventsByNode Resolver
// イベントを DynamoDB に保存する（ポーリング用）
// checkGroupExists Pipeline Function の後に実行されることを想定

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { groupId, domain, nodeId, events } = ctx.arguments;
  const serverTimestamp = util.time.nowISO8601();
  const ttl = util.time.nowEpochSeconds() + parseInt(ctx.env.MESH_EVENT_TTL_SECONDS || '10');

  const items = events.map(event => ({
    pk: `GROUP#${groupId}@${domain}`,
    sk: `EVENT#${serverTimestamp}#${util.autoId()}`,
    eventName: event.eventName,
    firedByNodeId: nodeId,
    groupId: groupId,
    domain: domain,
    payload: event.payload || null,
    timestamp: serverTimestamp,
    ttl: ttl
  }));

  return {
    operation: 'BatchWriteItem',
    tables: {
      [ctx.env.TABLE_NAME]: items.map(item => util.dynamodb.toMapValues(item))
    }
  };
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  // ctx.items は BatchWriteItem のレスポンスに含まれないため、
  // リクエスト時に使用した timestamp から次回の since を生成
  const serverTimestamp = util.time.nowISO8601();

  return {
    groupId: ctx.arguments.groupId,
    domain: ctx.arguments.domain,
    recordedCount: ctx.arguments.events.length,
    nextSince: `EVENT#${serverTimestamp}`
  };
}
