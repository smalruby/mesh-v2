// joinGroup Mutation Resolver
// ノードをグループに参加させる（TransactWriteItemsでアトミック実行）

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { groupId, domain, nodeId } = ctx.args;
  const now = util.time.nowISO8601();

  return {
    operation: 'TransactWriteItems',
    transactItems: [
      // 0. グループの存在確認 (ConditionCheck)
      {
        table: ctx.env.TABLE_NAME,
        operation: 'ConditionCheck',
        key: util.dynamodb.toMapValues({
          pk: `DOMAIN#${domain}`,
          sk: `GROUP#${groupId}#METADATA`
        }),
        condition: {
          expression: 'attribute_exists(pk)'
        }
      },
      // 1. グループ内のノード情報を追加
      {
        table: ctx.env.TABLE_NAME,
        operation: 'PutItem',
        key: util.dynamodb.toMapValues({
          pk: `DOMAIN#${domain}`,
          sk: `GROUP#${groupId}#NODE#${nodeId}`
        }),
        attributeValues: util.dynamodb.toMapValues({
          id: nodeId,
          nodeId: nodeId,
          groupId: groupId,
          domain: domain,
          name: `Node ${nodeId}`,
          joinedAt: now
        })
      },
      // 2. ノードの所属情報を作成（逆引き用）
      {
        table: ctx.env.TABLE_NAME,
        operation: 'PutItem',
        key: util.dynamodb.toMapValues({
          pk: `NODE#${nodeId}`,
          sk: 'METADATA'
        }),
        attributeValues: util.dynamodb.toMapValues({
          id: nodeId,
          nodeId: nodeId,
          groupId: groupId,
          domain: domain,
          name: `Node ${nodeId}`,
          joinedAt: now
        })
      }
    ]
  };
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  // TransactWriteItemsは個別のアイテムを返さないため、
  // リクエストパラメータからNode型を構築
  const { groupId, domain, nodeId } = ctx.args;

  return {
    id: nodeId,
    name: `Node ${nodeId}`,
    groupId: groupId,
    domain: domain
  };
}
