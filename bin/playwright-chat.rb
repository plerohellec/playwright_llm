#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require(:default)

# require 'playwright_llm'

require 'reline'
require 'logger'
require 'dotenv/load'

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

RubyLLM.configure do |config|
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.default_model = "google/gemini-2.5-flash-preview-09-2025"

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true

  config.logger = logger
end


provider = 'openrouter'
# provider = 'gemini'
# model = 'gemini-2.5-computer-use-preview-10-2025'
# model = 'x-ai/grok-code-fast-1'
model = 'google/gemini-2.5-flash-preview-09-2025'
# model = 'gemini-2.5-flash-preview-09-2025'

chat = RubyLLM::Chat.new(model: model, provider: provider)

streaming = false

agent = PlaywrightLlm::Agent.new(logger: logger, chat: chat)
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

