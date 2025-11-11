#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require(:default)

require 'optparse'
require 'logger'
require 'dotenv/load'

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
  opts.banner = "Usage: one_shot.rb [options] PROMPT"

  opts.on("--provider PROVIDER", "Provider (default: openrouter)") do |p|
    options[:provider] = p
  end

  opts.on("--model MODEL", "Model (default: google/gemini-2.5-flash-preview-09-2025)") do |m|
    options[:model] = m
  end
end.parse!

prompt = ARGV.join(' ')
if prompt.empty?
  puts "Error: PROMPT is required"
  exit 1
end

provider = options[:provider] || 'openrouter'
model = options[:model] || 'google/gemini-2.5-flash-preview-09-2025'

RubyLLM.configure do |config|
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.default_model = model

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true

  config.logger = logger
end

def fix_tool_call(tool_call, logger)
  logger.debug "\n[Tool Call] #{tool_call.name}"
  logger.debug "    with params #{tool_call.arguments}\n"

  # Gemini tends to mess up with the tool names by replacing '--' with '__'
  if tool_call.name =~ /^tools__/
    logger.debug "Renaming tool call from #{tool_call.name} to #{tool_call.name.gsub('tools__', 'tools--')}"
    tool_call.name.gsub!('tools__', 'tools--')
  end
end

tools = [ PlaywrightLlm::Tools::Navigate,
          PlaywrightLlm::Tools::SlimHtml,
          PlaywrightLlm::Tools::Click,
          PlaywrightLlm::Tools::FullHtml ]
chat = RubyLLM::Chat.new(model:, provider:)
            .with_tools(*tools)
            .on_tool_call { |tool_call| fix_tool_call(tool_call, logger) }

browser_tool = PlaywrightLlm::Browser.new(logger: logger)
logger.debug browser_tool.execute()

begin
  response = chat.ask(prompt)
  puts response.content
  puts "\n"
  input_tokens = response.input_tokens   # Tokens in the prompt sent TO the model
  output_tokens = response.output_tokens # Tokens in the response FROM the model
  cached_tokens = response.cached_tokens # Tokens served from the provider's prompt cache (if supported) - v1.9.0+

  logger.debug "Input Tokens: #{input_tokens}"
  logger.debug "Output Tokens: #{output_tokens}"
  logger.debug "Cached Prompt Tokens: #{cached_tokens}" if cached_tokens
  logger.debug "Total Tokens for this turn: #{input_tokens + output_tokens}."
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

browser_tool.close