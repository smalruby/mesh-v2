require_relative '../use_cases/create_group'
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
  else
    {
      statusCode: 400,
      body: JSON.generate({ error: "Unknown field: #{field_name}" })
    }
  end
rescue StandardError => e
  # エラーハンドリング
  {
    statusCode: 500,
    body: JSON.generate({ error: e.message, backtrace: e.backtrace })
  }
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
