class PlaywrightLlm::Tools::Navigate < RubyLLM::Tool
  description "Navigates the browser to the specified URL and returns the HTTP status code."
  param :url, desc: "The URL to navigate to", required: true

  def execute(url:)
    begin
      puts
      puts "============================"
      puts "Navigating to #{url}"
      puts "============================="

      script_path = File.join(__dir__, '../../../js/tools/plw_navigate.js')
      cmd = "node #{script_path} '#{url}'"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        puts "************************"
        puts "Navigation successful"
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