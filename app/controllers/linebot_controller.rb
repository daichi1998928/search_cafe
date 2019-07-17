class LinebotController < ApplicationController


 require 'line/bot'  # gem 'line-bot-api'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = "8c6ff931567e7b99b64c65f30c8dccc2"
      config.channel_token = "/YFpNuRECiXwdtMc6TQC0IenEKHEWOJP5vEOJk3bnh57C6/ggLkvPlXUGnatt35hRRaB/CxiRZMxx2ksGK4XC7FBotEbbMAFTx/MKIlNbAGKZ7JPPWyKGc4gDVWhDk0auW8foAS0qDGn9eKxZ9BHMwdB04t89/1O/w1cDnyilFU="
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
      area_result = URI.parse("https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=#{key_id}&address=#{URI.encode(address)}&outret=1&wifi=1&freeword=#{URI.encode('カフェ')}")
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
        response = "カフェ名:" + cafe_name
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
