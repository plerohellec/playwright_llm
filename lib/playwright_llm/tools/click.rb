class PlaywrightLlm::Tools::Click < RubyLLM::Tool
  description "Clicks on a selector on the current page and waits for the page to settle, then returns the HTTP status code."
  param :selector, desc: "The CSS selector to click on the page"

  def execute(selector:)
    logger = PlaywrightLlm.logger
    begin
      logger.info "============================"
      logger.info "Clicking selector '#{selector}'"
      logger.info "============================="
      script_path = File.join(__dir__, '../../../js/tools/plw_click.js')
      cmd = "node #{script_path} '#{selector}'"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        logger.info "============================="
        logger.info "Click successful: #{output}"
        logger.info "============================="
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