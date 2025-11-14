# frozen_string_literal: true

module PlaywrightLlm
  class Agent
    def initialize(rubyllm_chat: nil, provider: nil, model: nil)
      @logger = PlaywrightLlm.logger
      if rubyllm_chat.nil?
        @provider = provider || 'openrouter'
        @model = model || 'google/gemini-2.5-flash-preview-09-2025'
        @chat = nil
      else
        @provider = nil
        @model = nil
        @chat = rubyllm_chat
      end
      @browser_tool = nil
    end

    def self.from_chat(rubyllm_chat:)
      new(rubyllm_chat: rubyllm_chat)
    end

    def self.from_provider_model(provider:, model:)
      new(provider: provider, model: model)
    end

    def launch
      @browser_tool = PlaywrightLlm::Browser.new(logger: @logger)
      res = @browser_tool.execute()
      @logger.debug "Browser tool execution result: #{res.inspect}"
      raise PlaywrightLlm::BrowserLaunchError, "Failed to start browser tool" unless res[:success]

      tools = [ PlaywrightLlm::Tools::Navigate,
                PlaywrightLlm::Tools::SlimHtml,
                PlaywrightLlm::Tools::Click,
                PlaywrightLlm::Tools::FullHtml ]
      if @chat.nil?
        @chat = RubyLLM::Chat.new(model: @model, provider: @provider)
      end
      @chat = @chat.with_tools(*tools)
                  .on_tool_call { |tool_call| fix_tool_call(tool_call) }
    end

    def ask(prompt)
      @chat.ask(prompt)
    end

    def close
      @browser_tool.close if @browser_tool
    end

    private

    def fix_tool_call(tool_call)
      @logger.debug "\n[Tool Call] #{tool_call.name}"
      @logger.debug "    with params #{tool_call.arguments}\n"

      # Gemini tends to mess up with the tool names by replacing '--' with '__'
      if tool_call.name =~ /^tools__/
        @logger.warn "Renaming tool call from #{tool_call.name} to #{tool_call.name.gsub('tools__', 'tools--')}"
        tool_call.name.gsub!('tools__', 'tools--')
      end
    end
  end
end