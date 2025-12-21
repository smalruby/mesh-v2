require 'spec_helper'

RSpec.describe 'Leave Group API', type: :request do
  let(:domain) { "test-leave-#{Time.now.to_i}.example.com" }
  let(:host_id) { "host-leave-#{Time.now.to_i}" }
  let(:member1_id) { "member1-leave-#{Time.now.to_i}" }
  let(:member2_id) { "member2-leave-#{Time.now.to_i}" }

  describe 'leaveGroup mutation' do
    context '一般メンバーが退出する場合' do
      it 'メンバーがグループから退出できる' do
        # Setup: グループを作成
        group = create_test_group('Leave Test Group', host_id, domain)
        group_id = group['id']

        # Setup: メンバー1をグループに参加させる
        join_test_node(group_id, domain, member1_id)

        # Setup: メンバー2をグループに参加させる
        join_test_node(group_id, domain, member2_id)

        # Execute: メンバー1が退出
        query = File.read(File.join(__dir__, '../fixtures/mutations/leave_group.graphql'))
        response = execute_graphql(query, {
          groupId: group_id,
          domain: domain,
          nodeId: member1_id
        })

        # Verify: エラーがないこと
        expect(response['errors']).to be_nil

        # Verify: Nodeオブジェクトが返されること
        node = response['data']['leaveGroup']
        expect(node).not_to be_nil
        expect(node['id']).to eq(member1_id)
        expect(node['groupId']).to be_nil  # 退出後はnull
        expect(node['domain']).to be_nil   # 退出後はnull

        # Verify: グループにはメンバー2とホストのみが残っていること
        list_query = File.read(File.join(__dir__, '../fixtures/queries/list_groups_by_domain.graphql'))
        list_response = execute_graphql(list_query, { domain: domain })
        groups = list_response['data']['listGroupsByDomain']

        # グループがまだ存在することを確認
        expect(groups).not_to be_empty
        expect(groups.first['id']).to eq(group_id)
      end

      it '複数メンバーが順次退出できる' do
        # Setup: グループを作成
        group = create_test_group('Multi Leave Test Group', host_id, domain)
        group_id = group['id']

        # Setup: メンバー1, 2をグループに参加させる
        join_test_node(group_id, domain, member1_id)
        join_test_node(group_id, domain, member2_id)

        # Execute: メンバー1が退出
        query = File.read(File.join(__dir__, '../fixtures/mutations/leave_group.graphql'))
        response1 = execute_graphql(query, {
          groupId: group_id,
          domain: domain,
          nodeId: member1_id
        })

        expect(response1['errors']).to be_nil
        expect(response1['data']['leaveGroup']['id']).to eq(member1_id)

        # Execute: メンバー2が退出
        response2 = execute_graphql(query, {
          groupId: group_id,
          domain: domain,
          nodeId: member2_id
        })

        expect(response2['errors']).to be_nil
        expect(response2['data']['leaveGroup']['id']).to eq(member2_id)

        # Verify: グループにはホストのみが残っている
        list_query = File.read(File.join(__dir__, '../fixtures/queries/list_groups_by_domain.graphql'))
        list_response = execute_graphql(list_query, { domain: domain })
        groups = list_response['data']['listGroupsByDomain']

        expect(groups).not_to be_empty
        expect(groups.first['id']).to eq(group_id)
      end
    end

    context 'ホストが退出する場合（グループ解散）' do
      it 'ホストが退出するとグループ全体が削除される' do
        # Setup: グループを作成
        group = create_test_group('Host Leave Test Group', host_id, domain)
        group_id = group['id']

        # Setup: メンバーをグループに参加させる
        join_test_node(group_id, domain, member1_id)

        # Execute: ホストが退出（グループ解散）
        query = File.read(File.join(__dir__, '../fixtures/mutations/leave_group.graphql'))
        response = execute_graphql(query, {
          groupId: group_id,
          domain: domain,
          nodeId: host_id
        })

        # Verify: エラーがないこと
        expect(response['errors']).to be_nil

        # Verify: nullが返されること（ホスト退出の場合）
        expect(response['data']['leaveGroup']).to be_nil

        # Verify: グループが削除されていること
        list_query = File.read(File.join(__dir__, '../fixtures/queries/list_groups_by_domain.graphql'))
        list_response = execute_graphql(list_query, { domain: domain })
        groups = list_response['data']['listGroupsByDomain']

        # グループが存在しないこと
        matching_groups = groups.select { |g| g['id'] == group_id }
        expect(matching_groups).to be_empty
      end

      it 'ホストのみのグループでホストが退出できる' do
        # Setup: グループを作成（メンバーなし）
        group = create_test_group('Solo Host Leave Test', host_id, domain)
        group_id = group['id']

        # Execute: ホストが退出
        query = File.read(File.join(__dir__, '../fixtures/mutations/leave_group.graphql'))
        response = execute_graphql(query, {
          groupId: group_id,
          domain: domain,
          nodeId: host_id
        })

        # Verify
        expect(response['errors']).to be_nil
        expect(response['data']['leaveGroup']).to be_nil

        # Verify: グループが削除されていること
        list_query = File.read(File.join(__dir__, '../fixtures/queries/list_groups_by_domain.graphql'))
        list_response = execute_graphql(list_query, { domain: domain })
        groups = list_response['data']['listGroupsByDomain']

        matching_groups = groups.select { |g| g['id'] == group_id }
        expect(matching_groups).to be_empty
      end
    end

    context 'エラーケース' do
      it '存在しないグループからの退出はエラーになる' do
        query = File.read(File.join(__dir__, '../fixtures/mutations/leave_group.graphql'))
        response = execute_graphql(query, {
          groupId: 'non-existent-group',
          domain: domain,
          nodeId: member1_id
        })

        # エラーが返されること
        expect(response['errors']).not_to be_nil
        expect(response['errors'].first['message']).to include('Group not found')
      end
    end
  end
end
