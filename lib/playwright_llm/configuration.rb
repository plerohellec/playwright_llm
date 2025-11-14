require "logger"

module PlaywrightLlm
  class Configuration
    attr_accessor :node_path, :logger, :headless, :user_agent

    def initialize
      @node_path = '.'
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @headless = true
      @user_agent = nil
    end
  end
end
