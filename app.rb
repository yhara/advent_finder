# coding: utf-8
require 'singleton'
require 'pp'
require 'uri'
require 'json'

require 'mechanize'
require 'sinatra/base'
require 'sinatra/reloader'
require 'slim'
require 'sass'

class Scraper
  include Singleton
  LIMIT = 5

  def initialize
    @agent = Mechanize.new
  end

  IGNORE_USERS = %w(manga_osyo ne_sachirou katsyoshi )
  def twitter_url
    return "https://twitter.com/search/realtime?q=" + 
      ['"advent+calendar"', "OR", URI.encode("アドベント"),
        *IGNORE_USERS.map{|s| "-#{s}"},
        "lang%3Aja&src=typd"].join("+")
  end

  def qiita
    doc = @agent.get("http://qiita.com/advent-calendar").root
    return doc.search("a[href^='/advent-calendar/2012']").
      reject{|a| a['href'].end_with?("new")}.
      reject{|a| a.text == ">"}.
      slice(0, LIMIT).
      map{|a| 
        [a.text, "http://qiita.com#{a['href']}"]
      }
  end

  def atnd
    json_str = @agent.get(["http://api.atnd.org/events/?",
                          "keyword_or=advent,アドベント&",
                          "ym=201212&",
                          "count=100&",
                          "format=json"].join).body
    return JSON.parse(json_str)["events"].
      slice(0, LIMIT*4).
      map{|event|
        ["(#{event['updated_at']}) #{event['title']}", event['event_url']]
      }
  end
  
  def adventar
    doc = @agent.get("http://www.adventar.org/").root
    return doc.search("a[href^='/calendars/']").
      reject{|a| a['href'] =~ /new/}.
      reverse.
      slice(0, LIMIT).
      map{|a| 
        [a.text, "http://www.adventar.org#{a['href']}"]
      }
  end

  def partake
    json_str = @agent.post("http://partake.in/api/event/search", 
                           query: "advent",
                           category: "all",
                           sortOrder: "createdAt",
                           beforeDeadlineOnly: "true",
                           maxNum: 30).body
    return JSON.parse(json_str)["events"].
      slice(0, LIMIT).
      map{|event|
        pp event
        ["(#{event['createdAt']}) #{event['title']}",
          "http://partake.in/events/#{event['id']}"]
      }
  end

  def connpass
    json_str = @agent.get(["http://connpass.com/api/v1/event/?",
                           "keyword_or=advent,アドベント&",
                           "ym=201212&",
                           "count=100",
                           "format=json"].join).body
    return JSON.parse(json_str)["events"].
      slice(0, LIMIT).
      map{|event|
        ["(#{event['updated_at']}) #{event['title']}", event['event_url']]
      }
  end
end

class MyApp < Sinatra::Base
  configure(:development){ register Sinatra::Reloader }

  get '/' do
    slim :index  # renders views/index.slim
  end

  get '/screen.css' do
    sass :screen  # renders views/screen.sass as screen.css
  end
end
