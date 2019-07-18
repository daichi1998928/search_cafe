class LinebotController < ApplicationController


 require 'line/bot'  # gem 'line-bot-api'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
   }
  end

  def callback
    body = request.body.read #postされたjson形式の文字列を取得する
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    # puts "------------------------------------------"
    # puts body
    # puts "-------------------------------------------"
    # puts signature
    # puts "-------------------------------------------"
    unless client.validate_signature(body, signature)#リクエストヘッダーに含まれる署名を検証して、リクエストがLINEプラットフォームから送信されたことを確認する必要があります。
      head :bad_request
      #ステータスコードを表示する
    end

    events = client.parse_events_from(body) #postされたbodyを配列形式で返してくれる

    events.each { |event|
      address = event.message['text']
      # area_result = `curl -X GET https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=52d46e2c5dcf3ceb3925d5fa4ec7615b&address=#{URI.encode(address)}&outret=1&wifi=1&freeword=#{URI.encode('カフェ')}`  #ここでぐるなびAPIを叩く

      key_id = ENV['ACCESS_KEY']
      area_result = URI.parse("https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=#{key_id}&address=#{URI.encode(address)}&wifi=1&freeword=#{URI.encode('カフェ')}")
      json_result = Net::HTTP.get(area_result)
      hash_result = JSON.parse json_result

      if hash_result["error"]
        response = "#{address}駅付近にwifiと電源があるカフェがございません"
      end

      if hash_result["rest"] #ここでお店情報が入った配列となる
        cafes = hash_result["rest"]
        cafe = cafes.sample

        until cafe["access"]["station"].include?(address)
          cafe = cafes.sample
        end


        cafe_name = cafe["name"]
        cafe_url = cafe["url_mobile"]
        response = "[カフェ名]" + cafe_name + "\n" + "[ぐるなびURL]" + cafe_url
      end
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'text',
            text: response
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end





end
