require 'spec_helper'

RSpec.describe 'High-Frequency Mutations API', type: :request do
  let(:api_endpoint) { ENV['APPSYNC_ENDPOINT'] }
  let(:api_key) { ENV['APPSYNC_API_KEY'] }

  describe 'reportDataByNode mutation' do
    it 'ノードのデータを報告できる' do
      # テストグループを作成
      timestamp = Time.now.to_i
      test_domain = "test-#{timestamp}.example.com"
      group = create_test_group('Test Group', "host-#{timestamp}-001", test_domain)
      group_id = group['id']

      # ノードをグループに参加させる
      node_id = "node-#{timestamp}-001"
      join_test_node(group_id, test_domain, node_id)

      # データを報告
      query = File.read(File.join(__dir__, '../fixtures/mutations/report_data_by_node.graphql'))
      variables = {
        groupId: group_id,
        domain: test_domain,
        nodeId: node_id,
        data: [
          { key: 'temperature', value: '25.5' },
          { key: 'humidity', value: '60.0' }
        ]
      }

      response = execute_graphql(query, variables)

      expect(response['errors']).to be_nil
      expect(response['data']['reportDataByNode']).to include(
        'nodeId' => node_id,
        'groupId' => group_id,
        'domain' => test_domain
      )
      expect(response['data']['reportDataByNode']['data']).to be_an(Array)
      expect(response['data']['reportDataByNode']['data'].size).to eq(2)
      expect(response['data']['reportDataByNode']['data']).to include(
        { 'key' => 'temperature', 'value' => '25.5' },
        { 'key' => 'humidity', 'value' => '60.0' }
      )
      expect(response['data']['reportDataByNode']['timestamp']).to match_iso8601
    end

    it '高頻度でデータを報告できる（15 ops/sec）' do
      timestamp = Time.now.to_i
      test_domain = "test-#{timestamp}.example.com"
      group = create_test_group('Test Group', "host-#{timestamp}-002", test_domain)
      group_id = group['id']

      node_id = "node-#{timestamp}-002"
      join_test_node(group_id, test_domain, node_id)

      query = File.read(File.join(__dir__, '../fixtures/mutations/report_data_by_node.graphql'))

      # 15回連続でデータを報告
      responses = 15.times.map do |i|
        variables = {
          groupId: group_id,
          domain: test_domain,
          nodeId: node_id,
          data: [{ key: 'counter', value: i.to_s }]
        }
        execute_graphql(query, variables)
      end

      # すべて成功することを確認
      responses.each do |response|
        expect(response['errors']).to be_nil
        expect(response['data']['reportDataByNode']['nodeId']).to eq(node_id)
      end
    end
  end

  describe 'fireEventByNode mutation' do
    it 'ノードからイベントを発火できる' do
      timestamp = Time.now.to_i
      test_domain = "test-#{timestamp}.example.com"
      group = create_test_group('Test Group', "host-#{timestamp}-003", test_domain)
      group_id = group['id']

      node_id = "node-#{timestamp}-003"
      join_test_node(group_id, test_domain, node_id)

      query = File.read(File.join(__dir__, '../fixtures/mutations/fire_event_by_node.graphql'))
      variables = {
        groupId: group_id,
        domain: test_domain,
        nodeId: node_id,
        eventName: 'button_clicked',
        payload: '{"x": 100, "y": 200}'
      }

      response = execute_graphql(query, variables)

      expect(response['errors']).to be_nil
      expect(response['data']['fireEventByNode']).to include(
        'name' => 'button_clicked',
        'firedByNodeId' => node_id,
        'groupId' => group_id,
        'domain' => test_domain,
        'payload' => '{"x": 100, "y": 200}'
      )
      expect(response['data']['fireEventByNode']['timestamp']).to match_iso8601
    end

    it 'payloadなしでイベントを発火できる' do
      timestamp = Time.now.to_i
      test_domain = "test-#{timestamp}.example.com"
      group = create_test_group('Test Group', "host-#{timestamp}-004", test_domain)
      group_id = group['id']

      node_id = "node-#{timestamp}-004"
      join_test_node(group_id, test_domain, node_id)

      query = File.read(File.join(__dir__, '../fixtures/mutations/fire_event_by_node.graphql'))
      variables = {
        groupId: group_id,
        domain: test_domain,
        nodeId: node_id,
        eventName: 'simple_event'
      }

      response = execute_graphql(query, variables)

      expect(response['errors']).to be_nil
      expect(response['data']['fireEventByNode']).to include(
        'name' => 'simple_event',
        'firedByNodeId' => node_id,
        'groupId' => group_id,
        'domain' => test_domain
      )
      expect(response['data']['fireEventByNode']['payload']).to be_nil
    end

    it '高頻度でイベントを発火できる（2 ops/sec）' do
      timestamp = Time.now.to_i
      test_domain = "test-#{timestamp}.example.com"
      group = create_test_group('Test Group', "host-#{timestamp}-005", test_domain)
      group_id = group['id']

      node_id = "node-#{timestamp}-005"
      join_test_node(group_id, test_domain, node_id)

      query = File.read(File.join(__dir__, '../fixtures/mutations/fire_event_by_node.graphql'))

      # 2回連続でイベントを発火
      responses = 2.times.map do |i|
        variables = {
          groupId: group_id,
          domain: test_domain,
          nodeId: node_id,
          eventName: 'periodic_event',
          payload: i.to_s
        }
        execute_graphql(query, variables)
      end

      # すべて成功することを確認
      responses.each do |response|
        expect(response['errors']).to be_nil
        expect(response['data']['fireEventByNode']['firedByNodeId']).to eq(node_id)
      end
    end
  end
end
