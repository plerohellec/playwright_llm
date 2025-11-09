class PlaywrightLlm::Tools::SlimHtml < RubyLLM::Tool
  description "Uses the browser that was opened before to extract slimmed down HTML by removing scripts, styles, and cleaning attributes. Returns the cleaned HTML content one page at a time. Pass a page number to retrieve a specific chunk."
  param :page, desc: "The page number", required: false

  def execute(page: 1)
    begin
      puts
      puts "============================"
      puts "Slimming HTML and returning page #{page}."
      puts "============================="

      script_path = File.join(__dir__, '../../../js/tools/plw_slim_html.js')
      cmd = "node #{script_path} #{page}"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        RubyLLM.logger.info "************************"
        RubyLLM.logger.info "HTML slimmed successfully. Output length: #{output.length}"
        RubyLLM.logger.info "Page url: #{output.match(/page url: (.+)/)[1]}"
        RubyLLM.logger.info "************************"
        output
      else
        puts "Script execution failed with exit code #{exit_status}: #{output}"
        { error: "Script execution failed with exit code #{exit_status}: #{output}" }
      end
    rescue => e
      puts "Failed to execute script: #{e.class} - #{e.message}"
      { error: "Failed to execute script: #{e.message}" }
    end
  end
end