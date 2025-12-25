# frozen_string_literal: true

module PlaywrightLLM
  class Agent
    Response = Struct.new(:content)
    MAX_TOTAL_TOOL_CALLS = 100
    TRIMMING_THRESHOLD = 15
    KEEP_TOOL_CALLS = 10

    def initialize(rubyllm_chat: nil, provider: nil, model: nil, trimming_threshold: TRIMMING_THRESHOLD, max_total_tool_calls: MAX_TOTAL_TOOL_CALLS)
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
      @last_tool = nil
      @consecutive_count = 0
      @total_tool_calls = 0
      @trimming_threshold = trimming_threshold
      @max_total_tool_calls = max_total_tool_calls
    end

    def self.from_chat(rubyllm_chat:)
      new(rubyllm_chat: rubyllm_chat)
    end

    def self.from_provider_model(provider:, model:, trimming_threshold: TRIMMING_THRESHOLD, max_total_tool_calls: MAX_TOTAL_TOOL_CALLS)
      new(provider: provider, model: model, trimming_threshold: trimming_threshold, max_total_tool_calls: max_total_tool_calls)
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
        trim_messages_if_needed
      end
    end

    def ask(prompt)
      case prompt
      when '/debug'
        debugger
        Response.new("Debugger session completed")
      when '/chat_summary'
        Response.new(chat_summary)
      when '/trim_messages'
        stats = trim_messages
        Response.new({ success: "Messages trimmed", stats: stats })
      else
        @chat.ask(prompt)
      end
    end

    def chat_summary
      messages = @chat.messages.map { |msg| msg.to_h }
      messages.map do |msg_data|
        { role: msg_data[:role],
          content: msg_data[:content][0, 100],
          tool_calls: msg_data[:tool_calls] ? msg_data[:tool_calls].map { |id, call| [ call.name, call.arguments ] } : nil,
          input_tokens: msg_data[:input_tokens]
        }
      end
    end

    def trim_messages_if_needed
      max_messages = @trimming_threshold
      if @chat.messages.size > max_messages
        stats = trim_messages
        @logger.info "Trimmed chat messages: #{stats[:before]} -> #{stats[:after]}"
        @logger.debug "Current messages after trimming: #{JSON.pretty_generate(chat_summary)}"
      end
    end

    def trim_messages
      messages = @chat.messages
      before_count = messages.size
      keep = []

      # Keep first system message
      system_msg = messages.find { |m| m.role == :system }
      keep << system_msg if system_msg

      # Keep first and last user messages
      users = messages.select { |m| m.role == :user }
      if users.any?
        keep << users.first
        keep << users.last if users.size > 1
      end

      # Keep last KEEP_TOOL_CALLS assistant or tool messages
      assistant_tool = messages.each_with_index.select { |m, i| m.role == :assistant || m.role == :tool }.map { |m, i| { msg: m, index: i } }
      tool_calls = assistant_tool.last(KEEP_TOOL_CALLS)
      tool_calls.each { |item| keep << item[:msg] }

      # Sort by original order and remove duplicates
      keep.sort_by! { |m| messages.index(m) }
      keep.uniq!

      @chat.messages.replace(keep)

      { before: before_count, after: keep.size }
    end

    def close
      @browser_tool.close if @browser_tool
    end

    private

    def fix_tool_call(tool_call)
      @logger.debug "\n[Tool Call] #{tool_call.name}"
      @logger.debug "    with params #{tool_call.arguments}\n"

      # Gemini tends to mess up with the tool names by replacing '--' with '__'
      if tool_call.name =~ /tools__/
        @logger.warn "Renaming tool call from #{tool_call.name} to #{tool_call.name.gsub('tools__', 'tools--')}"
        tool_call.name.gsub!('__', '--')
      end
    end

    def track_tool_call(tool_call)
      @total_tool_calls += 1
      if @total_tool_calls > @max_total_tool_calls
        raise PlaywrightLLM::TooManyToolCallsError, "Total tool calls limit reached (#{@max_total_tool_calls})"
      end

      if tool_call.name == @last_tool
        @consecutive_count += 1
      else
        @last_tool = tool_call.name
        @consecutive_count = 1
      end

      if @consecutive_count > 10
        raise RuntimeError, "Can't call the same tool more than 10 times in a row"
      end
    end
  end
end