# frozen_string_literal: true

require "ruby_llm"

module PlaywrightLlm
  class Error < StandardError; end
  class BrowserLaunchError < StandardError; end

  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
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
