class PlaywrightLLM::Tools::SearchForm < RubyLLM::Tool
  description "Fills the input field in a form with a search term and submits the form."
  param :form_id, desc: "The id of the form element"
  param :search_term, desc: "The term to fill in the input field"

  def execute(form_id:, search_term:)
    logger = PlaywrightLLM.logger
    begin
      logger.info "============================"
      logger.info "Searching in form '#{form_id}' with term '#{search_term}'"
      script_path = File.join(__dir__, '../../../js/tools/plw_search_form.js')
      cmd = "node #{script_path} '#{form_id}' '#{search_term}'"
      output = `#{cmd} 2>&1`
      exit_status = $?.exitstatus

      output.lines.each do |line|
        if line =~ /PLWLLM_LOG: (.+)/
          logger.info $1
        end
      end
      output.gsub!(/PLWLLM_LOG: /, '')

      if exit_status == 0
        logger.info "Search successful"
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