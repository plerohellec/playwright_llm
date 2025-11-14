class PlaywrightLLM::Tools::Executor < RubyLLM::Tool
  description "Executes a Playwright js script and returns the output. The script must first import the necessary Playwright modules and launch a chromium browser instance, navigate to the desired URL, perform actions, and then close the browser."
  param :script_code, desc: "The Playwright js script code to execute as a string"

  def execute(script_code:)
    begin
      puts
      puts "============================"
      puts "Executing Playwright script:"
      puts script_code
      puts "============================="
      temp_file = Tempfile.new(['playwright_script', '.js'], Rails.root.join('tmp').to_s)
      temp_file.write(script_code)
      temp_file.close

      cmd = "node #{temp_file.path}"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      temp_file.unlink

      if exit_status == 0
        puts "************************"
        puts "Script executed successfully. Output:"
        puts output
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