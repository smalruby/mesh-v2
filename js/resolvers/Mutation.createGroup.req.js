// createGroup Mutation Resolver - Request Handler
// グループを作成し、Domain対応のメタデータを保存

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { name, hostId, domain } = ctx.args;

  // Domain決定: 引数 > ソースIP
  const sourceIp = ctx.identity.sourceIp[0];
  const actualDomain = domain || sourceIp;

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
