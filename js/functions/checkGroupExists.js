// checkGroupExists Pipeline Before Function
// グループの存在確認を行う共通Function
// reportDataByNode, fireEventByNode の前処理として使用

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
  // グループが存在しない場合はエラー
  if (!ctx.result) {
    util.error(
      `Group ${ctx.args.groupId}@${ctx.args.domain} does not exist or has been dissolved`,
      'GroupNotFound'
    );
  }

  // グループ情報をcontextに保存（後続のfunctionで使用可能）
  ctx.stash.group = ctx.result;
  return ctx.result;
}
