// createGroup Mutation Resolver
// グループを作成し、Domain対応のメタデータを保存

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { name, hostId, domain } = ctx.args;

  // Domain決定: 引数 > ソースIP
  // domain引数が指定されていればsourceIPにアクセスしない
  const actualDomain = domain || ctx.identity?.sourceIp?.[0];

  // domainが取得できない場合はエラー
  if (!actualDomain) {
    util.error('Domain must be specified or source IP must be available', 'ValidationError');
  }

  // Domain文字列のバリデーション（最大256文字）
  if (actualDomain.length > 256) {
    util.error('Domain must be 256 characters or less', 'ValidationError');
  }

  // グループID生成
  const groupId = util.autoId();
  const fullId = `${groupId}@${actualDomain}`;
  const now = util.time.nowISO8601();

  return {
    operation: 'PutItem',
    key: util.dynamodb.toMapValues({
      pk: `DOMAIN#${actualDomain}`,
      sk: `GROUP#${groupId}#METADATA`
    }),
    attributeValues: util.dynamodb.toMapValues({
      id: groupId,
      domain: actualDomain,
      fullId: fullId,
      name: name,
      hostId: hostId,
      createdAt: now,
      // GSI用（groupId -> domain の逆引き検索）
      gsi_pk: `GROUP#${groupId}`,
      gsi_sk: `DOMAIN#${actualDomain}`
    })
  };
}

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
