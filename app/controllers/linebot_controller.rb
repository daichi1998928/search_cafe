class LinebotController < ApplicationController

 #コードレビューをお願いいたします。
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
    binding.pry
    events = client.parse_events_from(body) #postされたbodyを配列形式で返してくれる

    events.each { |event|
     if event.message['text'] != nil
        address = event.message['text']
        json_hash_result = search_from_text(address) 
     else
        latitude = event.message['latitude']
        longitude = event.message['longitude']
        json_hash_result = search_cafe_from_address(latitude,longitude)
     end

     if json_hash_result.has_key?("error")
        error_reply(event)
        next
      end

     if json_hash_result["rest"] #ここでお店情報が入った配列となる
      cafes = json_hash_result["rest"]
      cafe = cafes.shuffle.sample
      flex_response = reply(cafe)
      map_response = cafe_address(cafe)
     end

     success_reply(event,flex_response,map_response)
    }

    head :ok
  end

  private
  def search_from_text(address)
    key_id = ENV['ACCESS_KEY']
    area_result = URI.parse("https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=#{key_id}&address=#{URI.encode(address)}&wifi=1&freeword=#{URI.encode('カフェ')}")
    json_result = Net::HTTP.get(area_result)
    hash_result = JSON.parse(json_result)
  end
  
  def search_cafe_from_address(latitude,longitude)
    key_id = ENV['ACCESS_KEY']
    area_result = URI.parse("https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=#{key_id}&latitude=#{latitude}&longitude=#{longitude}&wifi=1&freeword=#{URI.encode('カフェ')}")
    json_result = Net::HTTP.get(area_result)
    hash_result = JSON.parse json_result
  end

  def error_reply(event)
    response = "送信していただいたエリアの付近にwifiがあるカフェをぐるなびから探すことはできませんでした。申し訳ございませんが他のツールをお使いください"
        case event
        when Line::Bot::Event::Message
          case event.type
          when Line::Bot::Event::MessageType::Text,Line::Bot::Event::MessageType::Location
            message = {
            type: 'text',
            text: response
          }
             client.reply_message(event['replyToken'], [message])
          end
        end
  end

  def success_reply(event,flex_response,map_response)
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text,Line::Bot::Event::MessageType::Location
         client.reply_message(event['replyToken'], [flex_response,map_response])
      end
    end

  end

  def reply(cafe)

    {
      "type": "flex",
      "altText": "this is a flex message",
      "contents": {
        "type": "bubble",
        "hero": {
          "type": "image",
          "url": cafe["image_url"]["shop_image1"].present? ? cafe["image_url"]["shop_image1"]:  "https://scdn.line-apps.com/n/channel_devcenter/img/fx/01_1_cafe.png",
          "size": "full",
          "aspectRatio": "20:13",
          "aspectMode": "cover",
          "action": {
            "type": "uri",
            "uri": "http://linecorp.com/"
          }
        },
        "body": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "text",
              "text": cafe["name"],
              "weight": "bold",
              "size": "lg"
            },
            {
              "type": "box",
              "layout": "vertical",
              "margin": "lg",
              "spacing": "md",
              "contents": [
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "md",
                  "contents": [
                    {
                      "type": "text",
                      "text": "予算",
                      "color": "#aaaaaa",
                      "size": "md",
                      "flex": 3
                    },
                    {
                      "type": "text",
                      "text": cafe["budget"].to_s,
                      "wrap": true,
                      "color": "#666666",
                      "size": "lg",
                      "flex": 5
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "md",
                  "contents": [
                    {
                      "type": "text",
                      "text": "定休日",
                      "color": "#aaaaaa",
                      "size": "md",
                      "flex": 3
                    },
                    {
                      "type": "text",
                      "text": cafe["holiday"].present? ? cafe["holiday"] : "",
                      "wrap": true,
                      "color": "#666666",
                      "size": "md",
                      "flex": 5
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "md",
                  "contents": [
                    {
                      "type": "text",
                      "text": "開店時間",
                      "color": "#aaaaaa",
                      "size": "md",
                      "flex": 3
                    },
                    {
                      "type": "text",
                      "text":  cafe["opentime"].present? ? cafe["opentime"] : "",
                      "wrap": true,
                      "color": "#666666",
                      "size": "md",
                      "flex": 5
                    }
                  ]
                }
              ]
            }
          ]
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "button",
              "style": "link",
              "height": "sm",
              "action": {
                "type": "uri",
                "label": "もっと詳しく！",
                "uri": cafe["url_mobile"],
              }
            },
            {
              "type": "spacer",
              "size": "sm"
            }
          ],
          "flex": 0
        }
      }
    }
  end

  def cafe_address(cafe)
    {
      "type": "location",
      "title": cafe["name"],
      "address": cafe["address"],
      "latitude": cafe["latitude"],
      "longitude": cafe["longitude"]
    }
   end



end
