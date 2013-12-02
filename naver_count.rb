#
# naver_count.rb : scrape list of urls from matome.naver.jp
#
require 'mechanize'
require 'pp'

if ARGV.size == 0
  puts "usage: #$0 2138329156390648001"
end

def adcals(page)
  doc = page.root
  return doc.search(".mdMTMWidget01ItemTtl01Link").map{|a|
    [a[:href], a.text.strip]
  }
end

def pages(page)
  doc = page.root
  return doc.at(".MdPagination03").text.split
end

agent = Mechanize.new

url = "http://matome.naver.jp/odai/#{ARGV[0]}"
page = agent.get(url)
adcals = pages(page).flat_map{|n|
  url = "http://matome.naver.jp/odai/#{ARGV[0]}?page=#{n}"
  page = agent.get(url)
  adcals(page)
}

adcals.each do |href, text|
  puts "#{href} #{text}"
end
