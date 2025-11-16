# frozen_string_literal: true

module PlaywrightLLM
  class Agent
    def initialize(rubyllm_chat: nil, provider: nil, model: nil)
      @logger = PlaywrightLLM.logger
      if rubyllm_chat.nil?
        raise ArgumentError, 'provider must be provided' if provider.nil?
        raise ArgumentError, 'model must be provided' if model.nil?
        @provider = provider
        @model = model
        @chat = RubyLLM::Chat.new(model: @model, provider: @provider)
      else
        @provider = nil
        @model = nil
        @chat = rubyllm_chat
      end
      @browser_tool = nil
      @tool_call_history = []
      @last_tool = nil
      @consecutive_count = 0
    end

    def self.from_chat(rubyllm_chat:)
      new(rubyllm_chat: rubyllm_chat)
    end

    def self.from_provider_model(provider:, model:)
      new(provider: provider, model: model)
    end

    def with_instructions(instructions)
      @chat = @chat.with_instructions(instructions)
      self
    end

    def with_tool(tool)
      @chat = @chat.with_tool(tool)
      self
    end

    def launch
      @browser_tool = PlaywrightLLM::Browser.new(logger: @logger)
      res = @browser_tool.execute()
      @logger.debug "Browser tool execution result: #{res.inspect}"
      raise PlaywrightLLM::BrowserLaunchError, "Failed to start browser tool" unless res[:success]

      tools = [ PlaywrightLLM::Tools::Navigate,
                PlaywrightLLM::Tools::SlimHtml,
                PlaywrightLLM::Tools::Click,
                PlaywrightLLM::Tools::FullHtml,
                PlaywrightLLM::Tools::SearchForm ]
      @chat = @chat.with_tools(*tools).on_tool_call do |tool_call|
        fix_tool_call(tool_call)
        track_tool_call(tool_call)
      end
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

    def track_tool_call(tool_call)
      if tool_call.name == @last_tool
        @consecutive_count += 1
      else
        @last_tool = tool_call.name
        @consecutive_count = 1
      end

      if @consecutive_count > 5
        raise RuntimeError, "You must not call the same tool more than 5 times in a row"
      end

      @tool_call_history << tool_call.name
    end
  end
end