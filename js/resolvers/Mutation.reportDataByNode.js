// reportDataByNode Mutation Resolver
// ノードのセンサーデータを報告（高頻度: 15 ops/sec per group）

import { util } from '@aws-appsync/utils';

export function request(ctx) {
  const { groupId, domain, nodeId, data } = ctx.args;
  const now = util.time.nowISO8601();

  // SensorDataInputをDynamoDB List形式に変換
  const sensorDataList = data.map(item => ({
    key: item.key,
    value: item.value
  }));

  return {
    operation: 'PutItem',
    key: util.dynamodb.toMapValues({
      pk: `DOMAIN#${domain}`,
      sk: `GROUP#${groupId}#NODE#${nodeId}#STATUS`
    }),
    attributeValues: util.dynamodb.toMapValues({
      nodeId: nodeId,
      groupId: groupId,
      domain: domain,
      data: sensorDataList,
      timestamp: now,
      // GSI用属性
      gsi_pk: `GROUP#${groupId}@${domain}`,
      gsi_sk: `NODE#${nodeId}`
    }),
    // 環境変数からテーブル名を取得
    // Note: AppSyncのPutItemではtableプロパティは不要（DataSourceで指定済み）
    // しかし、明示的に指定する場合は以下を追加:
    // table: ctx.env.TABLE_NAME
  };
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  // DynamoDBの結果からNodeStatus型を構築
  const item = ctx.result;

  return {
    nodeId: item.nodeId,
    groupId: item.groupId,
    domain: item.domain,
    data: item.data,
    timestamp: item.timestamp
  };
}
