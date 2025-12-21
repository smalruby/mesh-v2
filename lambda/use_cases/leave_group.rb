require_relative '../domain/group'
require_relative '../domain/node'

# LeaveGroup Use Case
# ビジネスロジック - グループ退出処理のフローを管理
class LeaveGroupUseCase
  def initialize(repository)
    @repository = repository
  end

  def execute(group_id:, domain:, node_id:)
    # 入力バリデーション
    validate_input!(group_id, domain, node_id)

    # グループ情報を取得
    group = @repository.find_group(group_id, domain)
    raise StandardError, "Group not found: #{group_id}@#{domain}" unless group

    # ホスト判定
    if group.host_id == node_id
      # ホスト退出 → グループ解散
      handle_host_leaving(group_id, domain)
    else
      # 一般メンバー退出 → メンバー削除
      handle_member_leaving(group_id, domain, node_id)
    end
  end

  private

  def validate_input!(group_id, domain, node_id)
    raise ArgumentError, 'group_id is required' if group_id.nil? || group_id.to_s.empty?
    raise ArgumentError, 'domain is required' if domain.nil? || domain.to_s.empty?
    raise ArgumentError, 'node_id is required' if node_id.nil? || node_id.to_s.empty?
  end

  def handle_host_leaving(group_id, domain)
    # グループ全体を削除
    success = @repository.dissolve_group(group_id, domain)
    raise StandardError, "Failed to dissolve group: #{group_id}@#{domain}" unless success

    # ホスト退出の場合はnilを返す（GraphQLではNode?型なのでnull可能）
    nil
  end

  def handle_member_leaving(group_id, domain, node_id)
    # メンバーをグループから削除
    success = @repository.remove_node_from_group(group_id, domain, node_id)
    raise StandardError, "Failed to remove node from group: #{node_id}" unless success

    # 退出後のNodeオブジェクトを返す（group_idとdomainはnil）
    Node.new(
      id: node_id,
      name: "Node #{node_id}",
      group_id: nil,
      domain: nil
    )
  end
end
