require_relative "../domain/group"
require "securerandom"
require "time"

# CreateGroup Use Case
# ビジネスロジック - グループ作成の処理フローを管理
class CreateGroupUseCase
  def initialize(repository)
    @repository = repository
  end

  def execute(name:, host_id:, domain:, use_websocket: true)
    # ビジネスロジック: 既存グループチェック（冪等性の実装）
    existing_group = @repository.find_group_by_host_and_domain(host_id, domain)
    return existing_group if existing_group

    polling_interval = use_websocket ? nil : (ENV["MESH_POLLING_INTERVAL_SECONDS"] || 2).to_i
    max_conn_seconds = (ENV["MESH_MAX_CONNECTION_TIME_SECONDS"] || 1500).to_i
    now = Time.now.utc
    expires_at = (now + max_conn_seconds).iso8601

    # 新規グループ作成
    group = Group.new(
      id: generate_id,
      name: name,
      host_id: host_id,
      domain: domain,
      created_at: now.iso8601,
      expires_at: expires_at,
      use_websocket: use_websocket,
      polling_interval_seconds: polling_interval
    )

    @repository.save_group(group)
    group
  end

  private

  def generate_id
    SecureRandom.uuid
  end
end
