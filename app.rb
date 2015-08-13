# app.rb
require 'sinatra'
require 'dotenv'
require 'slack'
require 'json'
require 'httparty'
require 'pp'
require 'csv'
require 'uri'

Dotenv.load

class Whois < Sinatra::Base
  post '/' do
    content_type :json

    Slack.configure do |config|
      config.token = ENV['SLACK_API_TOKEN']
    end

    client = Slack::Client.new

    subject = params[:text]
    user_name = params[:user_name]

    slack_user = client.users_list['members'].find { |u| u["name"] == subject }

    response = HTTParty.get("#{ENV['TEAM_NAV_API']}members")
    user_list = JSON.parse(response.body)

    artsy_user = user_list.find do |u|
      "#{u['email']}artsymail.com" == slack_user['profile']['email']
    end

    headshot = artsy_user['headshot'] ? artsy_user['headshot'] : slack_user['profile']['image_192']

    attachments = [{
        title: "#{artsy_user['name']}",
        text: "",
        thumb_url: "#{embedly_url(headshot)}",
        fields: [
          {
            title: "Title",
            value: "#{artsy_user['title']}",
            short: false
          },
          {
            title: "Team",
            value: "#{artsy_user['team']}",
            short: true
          }
        ]
      }]

    args = {
      channel: "@#{user_name}",
      text: "",
      username: "Artsy",
      icon_url: "https://www.artsy.net/images/icon-150.png",
      attachments: attachments.to_json
    }

    client.chat_postMessage args
    status 200
    body ''
  end

  def embedly_url(img)
    uri = URI::HTTP.build(
      host: "i.embed.ly",
      path: "/1/display/crop",
      query: URI.encode_www_form({
        url: img,
        width: 200,
        height: 200,
        quality: 90,
        grow: false,
        key: ENV['EMBEDLY_KEY']
      })
    )
    puts uri
    uri
  end
end