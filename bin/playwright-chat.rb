#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require(:default)

# require 'playwright_llm'

require 'optparse'
require 'reline'
require 'logger'
require 'dotenv/load'
require 'debug'

puts "Playwright Chat CLI"
puts "Type your message, press Enter on an empty line to send."
puts "Type 'exit' or 'quit' on a single line to end the conversation."
puts "=" * 50

class LogFormatter
  TIME_FORMAT = '%H:%M:%S'
  def call(severity, datetime, progname, msg)
    "#{datetime.strftime(TIME_FORMAT)} #{severity[0]}: #{msg}\n"
  end
end

logger = Logger.new(STDOUT)
logger.formatter = LogFormatter.new
logger.level = Logger::INFO

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: playwright-chat.rb [options]"

  opts.on("--[no-]headless", "Run Playwright headless (default: headless)") do |value|
    options[:headless] = value
  end

  opts.on("--user-agent USER_AGENT", "Custom user agent for Playwright") do |ua|
    options[:user_agent] = ua
  end

  opts.on("--[no-]parallel-search", "Enable the ParallelSearch tool (default: disabled)") do |value|
    options[:parallel_search] = value
  end
end.parse!(ARGV.clone)

provider = 'openrouter'
model    = 'google/gemini-2.5-flash-preview-09-2025'
# provider = 'gemini'
# model = 'gemini-2.5-computer-use-preview-10-2025'
# model = 'x-ai/grok-code-fast-1'
# model = 'gemini-2.5-flash-preview-09-2025'


RubyLLM.configure do |config|
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']

  config.use_new_acts_as = true
  config.logger = logger
end

user_agent = options[:user_agent] || ENV['PLAYWRIGHT_LLM_USER_AGENT'] || "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36"
headless = options.key?(:headless) ? options[:headless] : true

PlaywrightLLM.configure do |config|
  config.logger = logger
  config.headless = headless
  config.user_agent = user_agent
end

agent = PlaywrightLLM::Agent.from_provider_model(provider:, model:)
# chat = RubyLLM::Chat.new(model: model, provider: provider)
# agent = PlaywrightLLM::Agent.from_chat(rubyllm_chat: chat)


streaming = false

agent.with_instructions(<<~INSTRUCTIONS)
  You are an AI agent that uses a Playwright-controlled browser to navigate and interact with web pages to find information and answer user questions.
  Follow these guidelines when using the browser tools:
  - Pay attention to cookie banners on websites, dismiss them before digging.
  - When clicking with a selector, prefer the id attribute when available.
  - Do not ask for the full html of anything unless you absolutely have to.
  - Never include p or span elements in your selectors.

INSTRUCTIONS

if options[:parallel_search]
  agent.with_tool(PlaywrightLLM::Tools::ParallelSearch)
end

agent.launch

loop do
  lines = []
  loop do
    begin
      line = Reline.readline(lines.empty? ? "> " : "  ", true)
      break if line.nil?
      lines << line
      break if line.empty?
    rescue Interrupt
      puts "\nInput cancelled. Starting new prompt."
      lines = []
      break
    end
  end
  input = lines.join("\n").strip
  break if lines.size == 2 && (lines[0].downcase == 'exit' || lines[0].downcase == 'quit')

  next if input.empty?

  begin
    if streaming
      response = ""
      agent.ask(input) do |chunk|
        if chunk.content
          print chunk.content
          response += chunk.content
        end
      end
    else
      response = agent.ask(input)
      puts response.content
      puts "\n"
      input_tokens = response.input_tokens   # Tokens in the prompt sent TO the model
      output_tokens = response.output_tokens # Tokens in the response FROM the model
      cached_tokens = response.cached_tokens # Tokens served from the provider's prompt cache (if supported) - v1.9.0+

      logger.debug "Input Tokens: #{input_tokens}"
      logger.debug "Output Tokens: #{output_tokens}"
      logger.debug "Cached Prompt Tokens: #{cached_tokens}" if cached_tokens
      logger.debug "Total Tokens for this turn: #{input_tokens + output_tokens}."
    end
    puts "\n\n"
  rescue Interrupt
    puts "\n\nInterrupted. Ready for next prompt."
  rescue => e
    logger.error "Error: #{e.class} - #{e.message}"

    if e.class == RubyLLM::RateLimitError && e.message =~ /Please retry in ([\d.]+)s/
      sleep_time = $1.to_f + 3
      sleep sleep_time
      retry
    else
      logger.error e.backtrace.join("\n")
    end
  end
end

puts "Goodbye!"
agent.close

