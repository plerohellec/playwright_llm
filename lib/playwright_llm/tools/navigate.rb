class PlaywrightLlm::Tools::Navigate < RubyLLM::Tool
  description "Navigates the browser to the specified URL and returns the HTTP status code."
  param :url, desc: "The URL to navigate to", required: true

  def execute(url:)
    logger = RubyLLM.logger
    begin
      logger.info "============================"
      logger.info "Navigating to #{url}"
      logger.info "============================="
      script_path = File.join(__dir__, '../../../js/tools/plw_navigate.js')
      cmd = "node #{script_path} '#{url}'"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        logger.info "************************"
        logger.info "Navigation successful"
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