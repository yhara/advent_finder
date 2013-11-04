# coding: utf-8
require 'singleton'
require 'pp'
require 'uri'
require 'json'
require 'fileutils'

require 'mechanize'
require 'sinatra/base'
require 'sinatra/reloader'
require 'rack/utils'
require 'slim'
require 'sass'

class Scraper
  include Singleton
  include Rack::Utils # escape, escape_html
  LIMIT = 5

  def initialize
    @agent = Mechanize.new
  end

  IGNORE_USERS = %w(manga_osyo ne_sachirou katsyoshi gift_present_jp)
  def twitter_url
    return "https://twitter.com/search/realtime?q=" + 
      ['"advent+calendar"', "OR", URI.encode("アドベント+カレンダー"), "OR", URI.encode("アドベントカレンダー"),
        *IGNORE_USERS.map{|s| "-#{s}"},
        "lang%3Aja&src=typd"].join("+")
  end

  def qiita
    doc = @agent.get("http://qiita.com/advent-calendar/2013").root
    links = doc.search("a.calendar-name")
    
    FileUtils.touch("qiita_cache.txt")
    FileUtils.touch("qiita_last.txt")
    File.write("qiita_curr.txt", format_qiita_links(links))
    if (diff = `diff qiita_last.txt qiita_curr.txt`).empty?
      diff = File.read("qiita_cache.txt")
    else
      File.write("qiita_last.txt", format_qiita_links(links))
      File.write("qiita_cache.txt", diff)
    end

    return diff
  end

  def format_qiita_links(links)
    return links.map{|a|
      "#{a.text.strip} -- http://qiita.com/#{a[:href]}\n"
    }.join
  end
  private :format_qiita_links

  def event_atnd
    json_str = @agent.get(["http://api.atnd.org/eventatnd/event/?",
                          "keyword_or=advent,アドベント&",
                          "ym=201312&",
                          "count=100&",
                          "format=json"].join).body
    return JSON.parse(json_str)["events"].
      slice(0, LIMIT*4).
      map{|_event|
        event = _event["event"][0]
        ["(#{event['updated_at']}) #{event['title']}", event['event_url']]
      }
  end
  
  def adventar
    doc = @agent.get("http://www.adventar.org/").root
    return doc.search("a[href^='/calendars/'][style^='background']").
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
                           "ym=201312&",
                           "count=100",
                           "format=json"].join).body
    return JSON.parse(json_str)["events"].
      slice(0, LIMIT).
      map{|event|
        ["(#{event['updated_at']}) #{event['title']}", event['event_url']]
      }
  end

  def zusaar
    json_str = @agent.get(["http://www.zusaar.com/api/event/?",
                           "keyword_or=advent,アドベント&",
                           "ym=201312&",
                           "count=100&",
                           "format=json"].join).body
    return JSON.parse(json_str)["event"].
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
