# frozen_string_literal: true

require "logger"
require "ruby_llm"

require_relative "playwright_llm/configuration"

module PlaywrightLLM
  class Error < StandardError; end
  class BrowserLaunchError < StandardError; end

  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end

    def logger
      config.logger
    end

    def logger=(logger)
      config.logger = logger
    end
  end

  module Tools
  end
end

require_relative "playwright_llm/version"
require_relative "playwright_llm/browser"
require_relative "playwright_llm/agent"
require_relative "playwright_llm/tools/click"
require_relative "playwright_llm/tools/executor"
require_relative "playwright_llm/tools/full_html"
require_relative "playwright_llm/tools/navigate"
require_relative "playwright_llm/tools/slim_html"
