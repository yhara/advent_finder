require 'singleton'
require 'pp'

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
    json_str = @agent.get("http://api.atnd.org/events/", 
                          keyword: "advent",
                          ym: "201212",
                          count: 100,
                          format: "json").body
    return JSON.parse(json_str)["events"].
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
