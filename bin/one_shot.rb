#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require(:default)

require 'optparse'
require 'logger'
require 'dotenv/load'
require 'debug'

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

  opts.on("--[no-]headless", "Run Playwright headless (default: headless)") do |value|
    options[:headless] = value
  end

  opts.on("--user-agent USER_AGENT", "Custom user agent string for Playwright") do |ua|
    options[:user_agent] = ua
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

PlaywrightLLM.configure do |config|
  config.logger = logger
  config.headless = options.key?(:headless) ? options[:headless] : true
  config.user_agent = options[:user_agent] || ENV['PLAYWRIGHT_LLM_USER_AGENT']
end

begin
  agent = PlaywrightLLM::Agent.new(provider: provider, model: model)
  res = agent.start
  puts "Agent started with provider=#{provider}, model=#{model}"

  response = agent.ask(prompt)
  puts response.content
  puts "\n"
  input_tokens = response.input_tokens   # Tokens in the prompt sent TO the model
  output_tokens = response.output_tokens # Tokens in the response FROM the model
  cached_tokens = response.cached_tokens # Tokens served from the provider's prompt cache (if supported) - v1.9.0+

  logger.debug "Input Tokens: #{input_tokens}"
  logger.debug "Output Tokens: #{output_tokens}"
  logger.debug "Cached Prompt Tokens: #{cached_tokens}" if cached_tokens
  logger.debug "Total Tokens for this turn: #{input_tokens + output_tokens}."

rescue Interrupt
  puts "\nExecution interrupted by user."
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

agent.close