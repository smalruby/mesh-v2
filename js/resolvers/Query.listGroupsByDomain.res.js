// listGroupsByDomain Query Resolver - Response Handler
// DynamoDBアイテムをGroup型の配列に変換

import { util } from '@aws-appsync/utils';

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  // DynamoDBアイテムをGroup型に変換
  // METADATAサフィックスを持つアイテムのみを抽出
  return ctx.result.items
    .filter(item => item.sk.endsWith('#METADATA'))
    .map(item => ({
      id: item.id,
      domain: item.domain,
      fullId: item.fullId,
      name: item.name,
      hostId: item.hostId,
      createdAt: item.createdAt
    }));
}
