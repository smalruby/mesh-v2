// createGroup Mutation Resolver - Request Handler
// グループを作成し、Domain対応のメタデータを保存

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { name, hostId, domain } = ctx.args;

  // Domain文字列のバリデーション（最大256文字）
  if (domain.length > 256) {
    util.error('Domain must be 256 characters or less', 'ValidationError');
  }

  // グループID生成
  const groupId = util.autoId();
  const fullId = `${groupId}@${domain}`;
  const now = util.time.nowISO8601();

  return {
    operation: 'PutItem',
    key: util.dynamodb.toMapValues({
      pk: `DOMAIN#${domain}`,
      sk: `GROUP#${groupId}#METADATA`
    }),
    attributeValues: util.dynamodb.toMapValues({
      id: groupId,
      domain: domain,
      fullId: fullId,
      name: name,
      hostId: hostId,
      createdAt: now,
      // GSI用（groupId -> domain の逆引き検索）
      gsi_pk: `GROUP#${groupId}`,
      gsi_sk: `DOMAIN#${domain}`
    })
  };
}
