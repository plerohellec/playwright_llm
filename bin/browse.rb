#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require(:default)

require 'optparse'
require 'playwright_llm'

options = {}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: browse.rb [options]"

  opts.on("-u", "--url URL", "URL to navigate to") do |u|
    options[:url] = u
  end

  opts.on("-s", "--selector SELECTOR", "CSS selector to click") do |s|
    options[:selector] = s
  end
end
parser.parse!

if options[:url].nil? || options[:selector].nil?
  puts "URL and selector are required"
  puts parser.help
  exit 1
end

logger = PlaywrightLLM.logger

browser = PlaywrightLLM::Browser.new(logger: logger)
res = browser.execute()

unless res[:success]
  puts "Failed to launch browser: #{res[:error]}"
  exit 1
end

nav_tool = PlaywrightLLM::Tools::Navigate.new
nav_result = nav_tool.execute(url: options[:url])

if nav_result.is_a?(Hash) && nav_result[:error]
  puts "Navigation failed: #{nav_result[:error]}"
  browser.close
  exit 1
end

click_tool = PlaywrightLLM::Tools::Click.new
click_result = click_tool.execute(selector: options[:selector])

if click_result.is_a?(Hash) && click_result[:error]
  puts "Click failed: #{click_result[:error]}"
  browser.close
  exit 1
end

slim_tool = PlaywrightLLM::Tools::SlimHtml.new
html = slim_tool.execute()

if html.is_a?(Hash) && html[:error]
  puts "Slim HTML failed: #{html[:error]}"
  browser.close
  exit 1
end

puts html

browser.close