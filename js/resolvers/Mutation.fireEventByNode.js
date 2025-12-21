// fireEventByNode Mutation Resolver
// ノードからイベントを発火（中頻度: 2 ops/sec per group）
// None DataSource: ペイロードパススルー処理

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { groupId, domain, nodeId, eventName, payload } = ctx.args;

  // None DataSourceは空のリクエストを返す
  return {
    payload: {
      groupId,
      domain,
      nodeId,
      eventName,
      payload
    }
  };
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  const { groupId, domain, nodeId, eventName, payload } = ctx.args;
  const now = util.time.nowISO8601();

  // Event型を構築（Subscriptionトリガー用）
  return {
    name: eventName,
    firedByNodeId: nodeId,
    groupId: groupId,
    domain: domain,
    payload: payload || null,
    timestamp: now
  };
}
