#!/usr/bin/env ruby

require 'dotenv/load'
require 'ruby_llm/mcp'

class LogFormatter
  TIME_FORMAT = '%H:%M:%S'
  def call(severity, datetime, progname, msg)
    "#{datetime.strftime(TIME_FORMAT)} #{severity[0]}: #{msg}\n"
  end
end

logger = Logger.new(STDOUT)
logger.formatter = LogFormatter.new
logger.level = Logger::INFO

provider = 'openrouter'
model = 'google/gemini-2.5-flash-preview-09-2025'

RubyLLM.configure do |config|
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.default_model = model

  config.logger = logger
end

# client = RubyLLM::MCP.client(
#   name: "playwright-mcp",
#   transport_type: :streamable,
#   config: {
#       url: "http://localhost:8931/mcp",
#   },
# )

RubyLLM::MCP.configure do |config|
  config.logger = logger
end

client = RubyLLM::MCP.client(
  name: "playwright-mcp",
  transport_type: :stdio,
  config: {
    command: 'npx @playwright/mcp@latest',
  }
)

tools = client.tools

puts "Available tools:"
tools.each do |tool|
  puts "- #{tool.name}: #{tool.description}"
end


chat = RubyLLM.chat(model:, provider:)
chat.with_tools(*client.tools)

response = chat.ask("What's the title of https://www.vpsbenchmarks.com ? Use the Playwright tool to navigate to the page and extract the title.")
puts response.content