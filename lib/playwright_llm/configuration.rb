class PlaywrightLlm::Configuration
  attr_accessor :node_path

  def initialize
    @node_path= '.'
  end
end