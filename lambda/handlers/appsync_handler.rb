require_relative '../use_cases/create_group'
require_relative '../use_cases/leave_group'
require_relative '../repositories/dynamodb_repository'
require 'aws-sdk-dynamodb'
require 'json'

# AppSync Lambda Handler
# Adapter層 - AppSyncイベントの受け取りと値抽出のみ
def lambda_handler(event:, context:)
  # AppSyncイベントから値を抽出
  field_name = event['info']['fieldName']
  arguments = event['arguments']

  case field_name
  when 'createGroup'
    handle_create_group(arguments)
  when 'leaveGroup'
    handle_leave_group(arguments)
  else
    raise "Unknown field: #{field_name}"
  end
  # Note: AppSyncはLambdaから発生した例外を自動的にGraphQLエラーに変換する
  # rescue句は不要（エラーはそのまま伝播させる）
end

def handle_create_group(arguments)
  # DynamoDBクライアントとリポジトリの初期化
  dynamodb = Aws::DynamoDB::Client.new(region: ENV['AWS_REGION'] || 'ap-northeast-1')
  repository = DynamoDBRepository.new(dynamodb)

  # ユースケースの実行
  use_case = CreateGroupUseCase.new(repository)
  group = use_case.execute(
    name: arguments['name'],
    host_id: arguments['hostId'],
    domain: arguments['domain']
  )

  # AppSync形式にフォーマット
  format_group_response(group)
end

def format_group_response(group)
  {
    id: group.id,
    domain: group.domain,
    fullId: group.full_id,
    name: group.name,
    hostId: group.host_id,
    createdAt: group.created_at
  }
end

def handle_leave_group(arguments)
  # DynamoDBクライアントとリポジトリの初期化
  dynamodb = Aws::DynamoDB::Client.new(region: ENV['AWS_REGION'] || 'ap-northeast-1')
  repository = DynamoDBRepository.new(dynamodb)

  # ユースケースの実行
  use_case = LeaveGroupUseCase.new(repository)
  node = use_case.execute(
    group_id: arguments['groupId'],
    domain: arguments['domain'],
    node_id: arguments['nodeId']
  )

  # ホスト退出の場合はnilが返される
  return nil if node.nil?

  # AppSync形式にフォーマット
  format_node_response(node)
end

def format_node_response(node)
  {
    id: node.id,
    name: node.name,
    groupId: node.group_id,
    domain: node.domain
  }
end
