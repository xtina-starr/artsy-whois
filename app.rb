# app.rb
require 'sinatra'
require 'dotenv'
require 'slack-ruby-client'
require 'json'
require 'httparty'
require 'pp'
require 'csv'
require 'uri'
require './fields.rb'

Dotenv.load

class Whois < Sinatra::Base
  post '/' do
    Slack.configure do |config|
      config.token = ENV['SLACK_API_TOKEN']
    end

    client = Slack::Web::Client.new

    requester = params[:user_name]
    args = params[:text].split(' ')
    username = args[0].sub('@', '')
    channel = args[1] ? args[1] : "@#{requester}"

    slack_user = find_slack_profile(client, username)
    artsy_user = find_artsy_user(slack_user) if slack_user

    return body('Could not find user!') if slack_user.nil? || artsy_user.nil?

    headshot = artsy_user['headshot'].empty? ? slack_user['profile']['image_192'] : artsy_user['headshot']

    attachments = [{
      title: (artsy_user['name']).to_s,
      title_link: "#{ENV['TEAM_NAV_API']}/#{email_name(slack_user)}",
      text: '',
      fallback: "Info on #{artsy_user['name']}",
      color: '#6a0bc1',
      thumb_url: embedly_url(headshot).to_s,
      fields: Fields.new(artsy_user).array
    }]

    options = {
      channel: channel,
      text: '',
      username: 'Artsy',
      icon_url: 'https://www.artsy.net/images/icon-150.png',
      attachments: attachments.to_json
    }

    client.chat_postMessage options

    content_type :json
    status 200
    body ''
  end

  def find_slack_profile(client, username)
    slack_user = client.users_list['members'].find do |u|
      u['name'] == username
    end
  end

  def email_name(slack_user)
    slack_user['profile']['email'].split('@')[0]
  end

  def find_artsy_user(slack_user)
    user = email_name(slack_user)
    query = member_query(user)
    url = "#{ENV['TEAM_NAV_API']}/api?query=#{URI.escape(query)}"
    response = HTTParty.get(url, headers: { 'secret' => ENV['TEAM_API_TOKEN'], 'user-agent': 'artsy-whois' })
    JSON.parse(response.body)['data']['member']
  end

  def member_query(user)
    <<-GRAPHQL
      {
        member(email: "#{user}@") {
          _id
          handle
          name
          namePronounciation
          email
          title
          floor
          city
          headshot
          team
          teamID
          subteam
          subteamID
          productTeam
          productTeamID
          reportsTo
          roleText
          teamRank
          startDate
          slackHandle
          slackID
          slackPresence
          githubHandle
          githubHistory
          feedbackFormUrl
          writerAuthorId
          articleHistory {
            href
            name
          }
          timeZone
          timeZoneOffset
          timeZoneLabel
          slackProfile {
            facebook
            facebook_url
            instagram
            instagram_url
            twitter
            twitter_url
            website
            website_url
          }
        }
      }
    GRAPHQL
  end

  def embedly_url(img)
    uri = URI::HTTP.build(
      host: 'i.embed.ly',
      path: '/1/display/crop',
      query: URI.encode_www_form(
        url: img,
        width: 200,
        height: 200,
        quality: 90,
        grow: false,
        key: ENV['EMBEDLY_KEY'])
    )
    uri
  end
end
