require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'base64'
require 'uri'

# AppSync Subscription Helper
# AWS AppSyncのWebSocket Subscriptionをテストするためのヘルパー
class AppSyncSubscriptionHelper
  attr_reader :messages, :errors

  def initialize(api_url, api_key)
    @api_url = api_url
    @api_key = api_key
    @messages = []
    @errors = []
    @ws = nil
    @registered_subscriptions = {}
  end

  # WebSocket接続を確立
  def connect
    # AppSync WebSocket URL (HTTP → WSS)
    ws_url = @api_url.gsub('https://', 'wss://').gsub('/graphql', '/graphql/connect')

    # AppSync接続用のヘッダー
    headers = {
      'host' => URI.parse(@api_url).host
    }

    # WebSocket接続用のURLにAPI Keyを含める
    connection_params = {
      'header' => Base64.strict_encode64(JSON.generate({
        'x-api-key' => @api_key,
        'host' => URI.parse(@api_url).host
      })),
      'payload' => Base64.strict_encode64('{}')
    }

    full_url = "#{ws_url}?#{URI.encode_www_form(connection_params)}"

    @ws = Faye::WebSocket::Client.new(full_url, nil, { headers: headers })

    @ws.on :open do |event|
      puts "[WebSocket] Connected to AppSync"
      send_connection_init
    end

    @ws.on :message do |event|
      handle_message(event.data)
    end

    @ws.on :close do |event|
      puts "[WebSocket] Connection closed: #{event.code} #{event.reason}"
      @ws = nil
    end

    @ws.on :error do |event|
      error_msg = "[WebSocket] Error: #{event.message}"
      puts error_msg
      @errors << error_msg
    end
  end

  # Subscription登録
  def subscribe(subscription_query, variables = {}, subscription_id = nil)
    subscription_id ||= SecureRandom.uuid

    message = {
      'id' => subscription_id,
      'type' => 'start',
      'payload' => {
        'data' => JSON.generate({
          'query' => subscription_query,
          'variables' => variables
        }),
        'extensions' => {
          'authorization' => {
            'x-api-key' => @api_key,
            'host' => URI.parse(@api_url).host
          }
        }
      }
    }

    send_message(message)
    @registered_subscriptions[subscription_id] = { query: subscription_query, variables: variables }
    subscription_id
  end

  # Subscription登録解除
  def unsubscribe(subscription_id)
    message = {
      'id' => subscription_id,
      'type' => 'stop'
    }
    send_message(message)
    @registered_subscriptions.delete(subscription_id)
  end

  # 接続を閉じる
  def close
    if @ws
      @ws.close
      @ws = nil
    end
  end

  # メッセージ受信を待つ（タイムアウト付き）
  def wait_for_message(timeout: 5)
    start_time = Time.now
    initial_count = @messages.length

    while Time.now - start_time < timeout
      sleep 0.1
      return @messages.last if @messages.length > initial_count
    end

    nil
  end

  # 複数メッセージを待つ
  def wait_for_messages(count, timeout: 10)
    start_time = Time.now
    initial_count = @messages.length

    while Time.now - start_time < timeout
      sleep 0.1
      return @messages.last(count) if @messages.length >= initial_count + count
    end

    @messages.last(count) rescue []
  end

  private

  def send_connection_init
    message = {
      'type' => 'connection_init'
    }
    send_message(message)
  end

  def send_message(message)
    if @ws
      @ws.send(JSON.generate(message))
      puts "[WebSocket] Sent: #{message['type']} (id: #{message['id']})"
    else
      puts "[WebSocket] Error: Not connected"
    end
  end

  def handle_message(data)
    message = JSON.parse(data)
    puts "[WebSocket] Received: #{message['type']} (id: #{message['id']})"

    case message['type']
    when 'connection_ack'
      puts "[WebSocket] Connection acknowledged"
    when 'start_ack'
      puts "[WebSocket] Subscription started: #{message['id']}"
    when 'data'
      puts "[WebSocket] Data received: #{message['payload']}"
      @messages << message
    when 'error'
      error_msg = "Subscription error: #{message['payload']}"
      puts "[WebSocket] #{error_msg}"
      @errors << error_msg
    when 'complete'
      puts "[WebSocket] Subscription completed: #{message['id']}"
    when 'ka'
      # Keep-alive message
    else
      puts "[WebSocket] Unknown message type: #{message['type']}"
    end
  rescue JSON::ParserError => e
    puts "[WebSocket] Failed to parse message: #{e.message}"
    @errors << "Parse error: #{e.message}"
  end
end

# EventMachineを使ったSubscriptionテスト実行ヘルパー
def run_subscription_test(timeout: 10, &block)
  result = nil
  error = nil

  EM.run do
    begin
      result = block.call
    rescue => e
      error = e
    end

    EM.add_timer(timeout) do
      EM.stop
    end
  end

  raise error if error
  result
end
