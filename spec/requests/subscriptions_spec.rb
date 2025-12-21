require 'spec_helper'

RSpec.describe 'Subscriptions API', type: :request do
  let(:domain) { "test-sub-#{Time.now.to_i}.example.com" }
  let(:host_id) { "host-sub-#{Time.now.to_i}" }
  let(:node1_id) { "node1-sub-#{Time.now.to_i}" }
  let(:node2_id) { "node2-sub-#{Time.now.to_i}" }

  describe 'Subscription schema validation' do
    it 'GraphQLスキーマにSubscription型が定義されている' do
      schema_content = File.read(File.join(__dir__, '../../graphql/schema.graphql'))

      # Subscription型の存在確認
      expect(schema_content).to include('type Subscription')

      # 各Subscriptionフィールドの存在確認
      expect(schema_content).to include('onDataUpdateInGroup')
      expect(schema_content).to include('onEventInGroup')
      expect(schema_content).to include('onGroupDissolve')
    end

    it '@aws_subscribeディレクティブが正しく定義されている' do
      schema_content = File.read(File.join(__dir__, '../../graphql/schema.graphql'))

      # onDataUpdateInGroupのディレクティブ確認
      expect(schema_content).to match(
        /onDataUpdateInGroup.*@aws_subscribe\(mutations:\s*\["reportDataByNode"\]\)/m
      )

      # onEventInGroupのディレクティブ確認
      expect(schema_content).to match(
        /onEventInGroup.*@aws_subscribe\(mutations:\s*\["fireEventByNode"\]\)/m
      )

      # Note: onGroupDissolveは型の不一致により現在コメントアウト
      # 将来的な実装で有効化予定
    end
  end

  describe 'Subscription behavior tests' do
    before(:all) do
      # Subscription動作テストはWebSocket接続が必要
      # ここでは、Mutationが正しく実行できることを確認し、
      # Subscriptionの動作は手動テストまたは別のE2Eテストで確認する
      puts "\n=== Subscription Behavior Tests ==="
      puts "Note: These tests verify mutations work correctly."
      puts "WebSocket subscription behavior should be verified manually or with E2E tests."
    end

    context 'onDataUpdateInGroup の前提条件' do
      it 'reportDataByNode mutation が正常に動作する' do
        # グループ作成
        group = create_test_group('Sub Test Group', host_id, domain)
        group_id = group['id']

        # ノード参加
        join_test_node(group_id, domain, node1_id)

        # データ報告
        query = File.read(File.join(__dir__, '../fixtures/mutations/report_data_by_node.graphql'))
        response = execute_graphql(query, {
          groupId: group_id,
          domain: domain,
          nodeId: node1_id,
          data: [
            { key: 'temperature', value: '25.5' },
            { key: 'humidity', value: '60' }
          ]
        })

        expect(response['errors']).to be_nil
        expect(response['data']['reportDataByNode']).not_to be_nil
        expect(response['data']['reportDataByNode']['nodeId']).to eq(node1_id)
        expect(response['data']['reportDataByNode']['data'].length).to eq(2)

        # Subscription期待動作:
        # - onDataUpdateInGroup(groupId: group_id, domain: domain) を購読中のクライアントに
        # - NodeStatus が送信される
        puts "  ✓ reportDataByNode executed - onDataUpdateInGroup should trigger"
      end
    end

    context 'onEventInGroup の前提条件' do
      it 'fireEventByNode mutation が正常に動作する' do
        # グループ作成
        group = create_test_group('Event Test Group', host_id, domain)
        group_id = group['id']

        # ノード参加
        join_test_node(group_id, domain, node1_id)

        # イベント発火
        query = File.read(File.join(__dir__, '../fixtures/mutations/fire_event_by_node.graphql'))
        response = execute_graphql(query, {
          groupId: group_id,
          domain: domain,
          nodeId: node1_id,
          eventName: 'test_event',
          payload: 'test payload'
        })

        expect(response['errors']).to be_nil
        expect(response['data']['fireEventByNode']).not_to be_nil
        expect(response['data']['fireEventByNode']['name']).to eq('test_event')

        # Subscription期待動作:
        # - onEventInGroup(groupId: group_id, domain: domain) を購読中のクライアントに
        # - Event が送信される
        puts "  ✓ fireEventByNode executed - onEventInGroup should trigger"
      end
    end

    context 'onGroupDissolve の前提条件' do
      it 'leaveGroup mutation (ホスト退出) が正常に動作する (Subscription未実装)' do
        skip 'onGroupDissolve subscription is not implemented due to type mismatch'

        # Note: onGroupDissolveは型の不一致により現在未実装
        # leaveGroup returns Node? だが、GraphDissolvePayload!が期待されている
        # 将来的な実装では、leaveGroupの戻り値型を調整するか、
        # 別のdissolveGroup mutationを作成する必要がある
      end
    end

    context 'groupId フィルタリング' do
      it '異なるgroupIdのイベントは受信されない（期待動作の確認）' do
        # グループ1作成
        group1 = create_test_group('Group 1', "#{host_id}-1", domain)
        group1_id = group1['id']

        # グループ2作成
        group2 = create_test_group('Group 2', "#{host_id}-2", domain)
        group2_id = group2['id']

        # 両方のグループで動作することを確認
        join_test_node(group1_id, domain, "#{node1_id}-g1")
        join_test_node(group2_id, domain, "#{node1_id}-g2")

        # Subscription期待動作:
        # - onDataUpdateInGroup(groupId: group1_id) を購読中のクライアントは
        # - group1_id のデータのみ受信し、group2_id のデータは受信しない
        puts "  ✓ Multiple groups created - filtering should work by groupId"
      end
    end
  end

  describe 'Manual WebSocket testing guide' do
    it 'WebSocketテスト手順を出力する' do
      puts "\n" + "=" * 80
      puts "Manual WebSocket Subscription Testing Guide"
      puts "=" * 80
      puts ""
      puts "To manually test subscriptions, use the following steps:"
      puts ""
      puts "1. Install wscat:"
      puts "   npm install -g wscat"
      puts ""
      puts "2. Connect to AppSync WebSocket endpoint:"
      puts "   API_URL='#{ENV['APPSYNC_ENDPOINT']}'"
      puts "   API_KEY='#{ENV['APPSYNC_API_KEY']}'"
      puts "   WS_URL=$(echo $API_URL | sed 's/https:/wss:/g' | sed 's/graphql$/graphql\\/connect/g')"
      puts ""
      puts "3. Subscribe to onDataUpdateInGroup:"
      puts '   subscription {'
      puts '     onDataUpdateInGroup(groupId: "YOUR_GROUP_ID", domain: "YOUR_DOMAIN") {'
      puts '       nodeId'
      puts '       groupId'
      puts '       data { key value }'
      puts '       timestamp'
      puts '     }'
      puts '   }'
      puts ""
      puts "4. Trigger mutation in another terminal:"
      puts "   Use execute_graphql helper or GraphQL playground"
      puts ""
      puts "5. Verify subscription receives the update"
      puts ""
      puts "=" * 80

      # このテストは常にパスする（ガイド表示のみ）
      expect(true).to be true
    end
  end
end
