// joinGroup Mutation Resolver - Response Handler
// TransactWriteItemsの結果からNode型を構築

import { util } from '@aws-appsync/utils';

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
