// getGroup Query Resolver
// groupIdとdomainからグループ情報を取得する

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { groupId, domain } = ctx.args;

  return {
    operation: 'GetItem',
    key: util.dynamodb.toMapValues({
      pk: `DOMAIN#${domain}`,
      sk: `GROUP#${groupId}#METADATA`
    })
  };
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  if (!ctx.result) {
    return null;
  }

  return {
    id: ctx.result.id,
    domain: ctx.result.domain,
    fullId: ctx.result.fullId,
    name: ctx.result.name,
    hostId: ctx.result.hostId,
    createdAt: ctx.result.createdAt,
    expiresAt: ctx.result.expiresAt
  };
}
