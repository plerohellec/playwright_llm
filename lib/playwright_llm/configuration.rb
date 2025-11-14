require "logger"

module PlaywrightLLM
  class Configuration
    attr_accessor :logger, :headless, :user_agent

    def initialize
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @headless = true
      @user_agent = nil
    end
  end
end
