class PlaywrightLLM::Tools::SlimHtml < RubyLLM::Tool
  description "Uses the browser that was opened before to extract slimmed down HTML by removing scripts, styles, and cleaning attributes. Returns the cleaned HTML content one chunk at a time. Pass a chunk number to retrieve a specific chunk."
  param :chunk, desc: "The chunk number", required: false

  def execute(chunk: 1)
    logger = PlaywrightLLM.logger
    begin
      logger.info
      logger.info "============================"
      logger.info "Slimming HTML and returning chunk #{chunk}."

      script_path = File.join(__dir__, '../../../js/tools/plw_slim_html.js')
      cmd = "node #{script_path} #{chunk}"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        logger.info "HTML slimmed successfully. Output length: #{output.length}"
        logger.info "Page url: #{output.match(/page url: (.+)/)[1]}"
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