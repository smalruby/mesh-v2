require 'json'
require 'net/http'
require 'uri'
require 'date'

RSpec.configure do |config|
  config.before(:suite) do
    # 環境変数チェック
    raise 'APPSYNC_ENDPOINT is not set' unless ENV['APPSYNC_ENDPOINT']
    raise 'APPSYNC_API_KEY is not set' unless ENV['APPSYNC_API_KEY']
  end

  # RSpecの設定
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

# GraphQL APIを実行するヘルパーメソッド
def execute_graphql(query, variables = {})
  uri = URI(ENV['APPSYNC_ENDPOINT'])
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  # テスト環境では証明書検証を無効化（AppSyncは信頼できるAWSサービス）
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(uri.path, {
    'Content-Type' => 'application/json',
    'x-api-key' => ENV['APPSYNC_API_KEY']
  })

  request.body = JSON.generate({
    query: query,
    variables: variables
  })

  response = http.request(request)
  JSON.parse(response.body)
end

# テスト用グループ作成ヘルパー
def create_test_group(name, host_id, domain)
  query = File.read(File.join(__dir__, 'fixtures/mutations/create_group.graphql'))
  execute_graphql(query, { name: name, hostId: host_id, domain: domain })
end

# カスタムマッチャー: ISO8601形式の日時文字列か確認
RSpec::Matchers.define :match_iso8601 do
  match do |actual|
    DateTime.iso8601(actual)
    true
  rescue ArgumentError
    false
  end

  failure_message do |actual|
    "expected #{actual} to be a valid ISO8601 datetime string"
  end
end

# カスタムマッチャー: 値が存在するか確認（nil, 空文字でない）
RSpec::Matchers.define :be_present do
  match do |actual|
    !actual.nil? && !actual.to_s.empty?
  end

  failure_message do |actual|
    "expected #{actual.inspect} to be present (not nil or empty)"
  end
end
