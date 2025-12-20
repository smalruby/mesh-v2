// listGroupsByDomain Query Resolver
// Domain内のグループ一覧を取得するクエリ

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  // Domain決定: 引数 > ソースIP
  // domain引数が指定されていればsourceIPにアクセスしない
  const domain = ctx.args.domain || ctx.identity?.sourceIp?.[0];

  // domainが取得できない場合はエラー
  if (!domain) {
    util.error('Domain must be specified or source IP must be available', 'ValidationError');
  }

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
