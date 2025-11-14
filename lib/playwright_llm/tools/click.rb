class PlaywrightLLM::Tools::Click < RubyLLM::Tool
  description "Clicks on a selector on the current page and waits for the page to settle, then returns the HTTP status code."
  param :selector, desc: "The CSS selector to click on the page"

  def execute(selector:)
    logger = PlaywrightLLM.logger
    begin
      logger.info "============================"
      logger.info "Clicking selector '#{selector}'"
      script_path = File.join(__dir__, '../../../js/tools/plw_click.js')
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
        logger.info "Click successful"
        logger.info "============================="

        logger.debug "Output: #{output.strip}"

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