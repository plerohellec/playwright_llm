class PlaywrightLlm::Tools::SlimHtml < RubyLLM::Tool
  description "Uses the browser that was opened before to extract slimmed down HTML by removing scripts, styles, and cleaning attributes. Returns the cleaned HTML content one page at a time. Pass a page number to retrieve a specific chunk."
  param :page, desc: "The page number", required: false

  def execute(page: 1)
    logger = PlaywrightLlm.logger
    begin
      logger.info
      logger.info "============================"
      logger.info "Slimming HTML and returning page #{page}."
      logger.info "============================="

      script_path = File.join(__dir__, '../../../js/tools/plw_slim_html.js')
      cmd = "node #{script_path} #{page}"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        logger.info "************************"
        logger.info "HTML slimmed successfully. Output length: #{output.length}"
        logger.info "Page url: #{output.match(/page url: (.+)/)[1]}"
        logger.info "************************"
        output
      else
        logger.error "Script execution failed with exit code #{exit_status}: #{output}"
        { error: "Script execution failed with exit code #{exit_status}: #{output}" }
      end
    rescue => e
      RubyLLM.logger.error "Failed to execute script: #{e.class} - #{e.message}"
      { error: "Failed to execute script: #{e.message}" }
    end
  end
end