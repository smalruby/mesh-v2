// listGroupsByDomain Query Resolver - Request Handler
// Domain内のグループ一覧を取得するクエリ

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  // Domain決定: 引数 > ソースIP
  const sourceIp = ctx.identity.sourceIp[0];
  const domain = ctx.args.domain || sourceIp;

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
