require "logger"

module PlaywrightLlm
  class Configuration
    attr_accessor :node_path, :logger

    def initialize
      @node_path = '.'
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
    end
  end
end
