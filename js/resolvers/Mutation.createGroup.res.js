// createGroup Mutation Resolver - Response Handler
// PutItemの結果からGroup型を構築

import { util } from '@aws-appsync/utils';

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  // DynamoDB PutItemの結果から直接Group型を返却
  return {
    id: ctx.result.id,
    domain: ctx.result.domain,
    fullId: ctx.result.fullId,
    name: ctx.result.name,
    hostId: ctx.result.hostId,
    createdAt: ctx.result.createdAt
  };
}
