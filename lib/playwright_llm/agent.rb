# frozen_string_literal: true

module PlaywrightLLM
  class Agent
    Response = Struct.new(:content)

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
          tool_calls: msg_data[:tool_calls] ? msg_data[:tool_calls].map { |id, call| call.name } : nil,
          input_tokens: msg_data[:input_tokens]
        }
      end
    end

    def trim_messages_if_needed
      max_messages = 12
      if @chat.messages.size > max_messages
        stats = trim_messages
        @logger.info "Trimmed chat messages: #{stats[:before]} -> #{stats[:after]}"
        @logger.debug "Current messages after trimming: #{chat_summary.inspect}"
      end
    end

    def trim_messages
      messages = @chat.messages
      before_messages_count = messages.size
      keep_messages = []

      # Add system message
      system_msg = messages.find { |m| m.role == :system }
      keep_messages << system_msg if system_msg

      # Add all user messages
      users = messages.select { |m| m.role == :user }
      keep_messages.concat(users)

      # Find tool pairs
      assistants_with_tools = messages.select { |m| m.role == :assistant && m.tool_calls && !m.tool_calls.empty? }
      pairs = []
      assistants_with_tools.each do |ass|
        idx = messages.index(ass)
        next_msg = messages[idx + 1]
        if next_msg && next_msg.role == :tool
          name = ass.tool_calls.values.first.name
          pairs << { assistant: ass, tool: next_msg, name: name, index: idx }
        end
      end

      # Classify successful and failed
      successful = pairs.reject { |p| p[:tool].content =~ /^\{.?error/ }
      failed = pairs.select { |p| p[:tool].content =~ /^\{.?error/ }

      # Last successful per name
      successful_by_name = successful.group_by { |p| p[:name] }
      last_successful = successful_by_name.map { |name, ps| ps.max_by { |p| p[:index] } }

      # Last failed
      last_failed = failed.last

      # Special handling for playwright_llm--tools--slim_html
      if pairs.last && pairs.last[:name] == "playwright_llm--tools--slim_html"
        consecutive_slim = []
        pairs.reverse_each do |p|
          if p[:name] == "playwright_llm--tools--slim_html"
            consecutive_slim << p
          else
            break
          end
        end
        # Remove the last_successful for slim_html
        last_successful.reject! { |p| p[:name] == "playwright_llm--tools--slim_html" }
        # Collect keep_pairs including consecutive slim
        keep_pairs = last_successful + [last_failed].compact + consecutive_slim
      else
        # Collect keep_pairs
        keep_pairs = last_successful + [last_failed].compact
      end

      # Add tool pairs to keep_messages
      keep_pairs.each do |p|
        keep_messages << p[:assistant]
        keep_messages << p[:tool]
      end

      # Always keep the last assistant message
      last_assistant = messages.reverse.find { |m| m.role == :assistant }
      keep_messages << last_assistant if last_assistant && !keep_messages.include?(last_assistant)

      # Sort by original order and remove duplicates
      keep_messages.sort_by! { |m| messages.index(m) }
      keep_messages.uniq!

      @chat.messages.replace(keep_messages)

      { before: before_messages_count, after: keep_messages.size }
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

      if @consecutive_count > 10
        raise RuntimeError, "Can't call the same tool more than 10 times in a row"
      end
    end
  end
end