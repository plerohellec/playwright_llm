class PlaywrightLLM::Tools::FullHtml < RubyLLM::Tool
  description "Extracts the full HTML content inside a given CSS selector from the current page. Returns an error if the selector does not exist."
  param :selector, desc: "The CSS selector to extract HTML from. Only id selectors (e.g., #myId) are permitted."

  def execute(selector:)
    unless selector =~ /^\S*#[a-zA-Z_-][\w-]*$/
      return { error: "Only id selectors (e.g., #myId) are permitted" }
    end

    logger = PlaywrightLLM.logger
    begin
      logger.info "============================"
      logger.info "Extracting full HTML from selector '#{selector}'"
      script_path = File.join(__dir__, '../../../js/tools/plw_full_html.js')
      cmd = "node #{script_path} '#{selector}'"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      output.lines.each do |line|
        if line =~ /PLWLLM_LOG: (.+)/
          logger.info $1
        end
      end
      output.gsub!(/PLWLLM_LOG: /, '')

      if exit_status == 0
        logger.info "HTML extracted successfully. Output length: #{output.length}"
        logger.info "============================"
        output
      else
        logger.error "Script execution failed with exit code #{exit_status}: #{output}"
        { error: "Script execution failed with exit code #{exit_status}: #{output}" }
      end
    rescue => e
      logger.error "Failed to execute script: #{e.class} - #{e.message}"
      { error: "Failed to execute script: #{e.message}" }
    end
  end
end
