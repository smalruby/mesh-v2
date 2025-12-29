// fireEventsByNode Mutation Resolver
// 複数イベントを一度に送信（1回のSubscriptionを発火）
// None DataSource: ペイロードパススルー処理

import { util } from '@aws-appsync/utils';

export function request(ctx) {
    const { groupId, domain, nodeId, events } = ctx.arguments;

    // None DataSourceは空のリクエストを返す
    return {
        payload: {
            groupId,
            domain,
            nodeId,
            events
        }
    };
}

export function response(ctx) {
    if (ctx.error) {
        util.error(ctx.error.message, ctx.error.type);
    }

    const { groupId, domain, nodeId, events } = ctx.arguments;

    // BatchEvent型を返す（1回のSubscriptionで複数イベントを配列として送信）
    return {
        events: events.map(event => ({
            name: event.eventName,
            firedByNodeId: nodeId,
            groupId: groupId,
            domain: domain,
            payload: event.payload || null,
            timestamp: event.firedAt
        })),
        firedByNodeId: nodeId,
        groupId: groupId,
        domain: domain,
        timestamp: util.time.nowISO8601()
    };
}
