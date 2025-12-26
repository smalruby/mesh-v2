// listGroupsByDomain Query Resolver - Request Handler
// Domain内のグループ一覧を取得するクエリ

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { domain } = ctx.args;

  return {
    operation: 'Query',
    query: {
      expression: 'pk = :pk AND begins_with(sk, :sk_prefix)',
      expressionValues: util.dynamodb.toMapValues({
        ':pk': `DOMAIN#${domain}`,
        ':sk_prefix': 'GROUP#'
      })
    }
  };
}
