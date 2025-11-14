class PlaywrightLlm::Tools::FullHtml < RubyLLM::Tool
  description "Extracts the full HTML content inside a given CSS selector from the current page. Returns an error if the selector does not exist."
  param :selector, desc: "The CSS selector to extract HTML from"

  def execute(selector:)
    logger = PlaywrightLlm.logger
    begin
      logger.info "============================"
      logger.info "Extracting full HTML from selector '#{selector}'"
      logger.info "============================="
      script_path = File.join(__dir__, '../../../js/tools/plw_full_html.js')
      cmd = "node #{script_path} '#{selector}'"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        logger.info "************************"
        logger.info "HTML extracted successfully. Output length: #{output.length}"
        logger.info "************************"
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
