class PlaywrightLlm::Tools::FullHtml < RubyLLM::Tool
  description "Extracts the full HTML content inside a given CSS selector from the current page. Returns an error if the selector does not exist."
  param :selector, desc: "The CSS selector to extract HTML from"

  def execute(selector:)
    begin
      puts
      puts "============================"
      puts "Extracting full HTML from selector '#{selector}'"
      puts "============================="

      script_path = File.join(__dir__, '../../../js/tools/plw_full_html.js')
      cmd = "node #{script_path} '#{selector}'"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        puts "************************"
        puts "HTML extracted successfully. Output length: #{output.length}"
        puts "************************"
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
