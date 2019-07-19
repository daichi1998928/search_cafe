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
        response = "#{address}付近にwifiと電源があるカフェがございません"
      end

      if hash_result["rest"] #ここでお店情報が入った配列となる
        cafes = hash_result["rest"]
        cafe_shuffles = cafes.shuffle
        cafe = cafe_shuffles.sample

        flex_response = reply(cafe)
      end
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          
          client.reply_message(event['replyToken'], flex_response)
        end
      end
    }

    head :ok
  end

  def reply(cafe)
    cafe_url = cafe["url_mobile"]
    cafe_name = cafe["name"]
    cafe_iamge = cafe["image_url"]["shop_image1"]
    open_time = cafe["opentime"]
    holiday = cafe["holiday"]
    cafe_budget = cafe["budget"].to_s

    if open_time.class != String #空いている時間と定休日の二つは空白の時にHashで返ってくるので、文字列に直そうとするとエラーになる。そのため、クラスによる場合分け。
         open_time = ""
      end
    if holiday.class != String
       holiday = ""
     end
    {
      "type": "flex",
      "altText": "this is a flex message",
      "contents": {
        "type": "bubble",
        "hero": {
          "type": "image",
          "url": cafe_iamge,
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
              "text": cafe_name,
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
                      "text": cafe_budget,
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
                      "text": holiday,
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
                      "text": open_time,
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
                "uri": cafe_url
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




end
