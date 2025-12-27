require "spec_helper"

RSpec.describe "Member Heartbeat API", type: :request do
  let(:domain) { "test-member-hb-#{Time.now.to_i}.example.com" }
  let(:host_id) { "host-member-hb-#{Time.now.to_i}" }
  let(:member_id) { "member-hb-#{Time.now.to_i}" }
  let(:group_name) { "Test Member Heartbeat Group" }

  describe "sendMemberHeartbeat mutation" do
    it "メンバーがハートビートを更新できる" do
      # 1. グループ作成
      group = create_test_group(group_name, host_id, domain)
      group_id = group["id"]

      # 2. メンバー参加
      join_test_node(group_id, domain, member_id)

      # 3. メンバーハートビート送信
      query = File.read(File.join(__dir__, "../fixtures/mutations/send_member_heartbeat.graphql"))
      response = execute_graphql(query, {
        groupId: group_id,
        domain: domain,
        nodeId: member_id
      })

      expect(response["errors"]).to be_nil
      expect(response["data"]["sendMemberHeartbeat"]).not_to be_nil
      expect(response["data"]["sendMemberHeartbeat"]["nodeId"]).to eq(member_id)
      expect(response["data"]["sendMemberHeartbeat"]["expiresAt"]).to match_iso8601
      expect(response["data"]["sendMemberHeartbeat"]["heartbeatIntervalSeconds"]).to be_an(Integer)

      # 有効期限の確認（環境変数のTTL設定に依存するが、ここでは値がセットされていることだけ確認）

      # デフォルトでは600秒（10分）後
      expires_time = DateTime.iso8601(response["data"]["sendMemberHeartbeat"]["expiresAt"]).to_time
      expect(expires_time).to be > Time.now
    end

    it "存在しないグループに対してメンバーハートビートを送るとエラー" do
      query = File.read(File.join(__dir__, "../fixtures/mutations/send_member_heartbeat.graphql"))
      response = execute_graphql(query, {
        groupId: "non-existent-group",
        domain: domain,
        nodeId: member_id
      })

      expect(response["errors"]).not_to be_nil
      expect(response["errors"][0]["errorType"]).to eq("GroupNotFound")
    end

    it "存在しないノードに対してメンバーハートビートを送るとエラー" do
      # 1. グループ作成
      group = create_test_group(group_name, host_id, domain)
      group_id = group["id"]

      # 2. 参加していないノードIDでハートビート送信
      query = File.read(File.join(__dir__, "../fixtures/mutations/send_member_heartbeat.graphql"))
      response = execute_graphql(query, {
        groupId: group_id,
        domain: domain,
        nodeId: "non-existent-node"
      })

      # Note: 現状の実装では、Nodeの存在チェックはUpdateItemのConditionExpressionで行われる
      # DynamoDB:ConditionalCheckFailedException が返るはずだが、AppSync function側で
      # これを NodeNotFound に変換しているか確認が必要
      expect(response["errors"]).not_to be_nil
      expect(response["errors"][0]["errorType"]).to eq("NodeNotFound")
    end

    it "ホストのheartbeat期限切れ時にメンバーハートビートがGroupNotFoundエラーを返す" do
      # 1. グループ作成
      group = create_test_group(group_name, host_id, domain)
      group_id = group["id"]

      # 2. メンバー参加
      join_test_node(group_id, domain, member_id)

      # 3. 61秒待機（TTL: 60秒）してホストのheartbeatを期限切れにする
      # Note: checkGroupExists.js では 1分(60秒)を閾値としている
      # テストを高速化するために、直接DynamoDBのアイテムを操作してheartbeatAtを古くすることも検討できるが、
      # ここではシンプルに sleep する（実際の動作確認）
      puts "Waiting 61 seconds for host heartbeat to expire..."
      sleep 61

      # 4. メンバーハートビート送信
      query = File.read(File.join(__dir__, "../fixtures/mutations/send_member_heartbeat.graphql"))
      response = execute_graphql(query, {
        groupId: group_id,
        domain: domain,
        nodeId: member_id
      })

      # GroupNotFoundエラーを期待
      expect(response["errors"]).not_to be_nil
      expect(response["errors"][0]["errorType"]).to eq("GroupNotFound")
      expect(response["errors"][0]["message"]).to include("Group not found")
    end
  end
end
