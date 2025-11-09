require 'open3'
require 'json'
require 'timeout'

class Tools::PlaywrightOpen
  def initialize(logger:)
    @logger = logger
    @wait_thr = nil
  end

  def execute
    launcher_path = File.join(__dir__, '../../js/launcher.js')
    cmd = "node #{launcher_path}"

    # Start child process in its own process group so it doesn't receive parent's signals
    stdin, stdout, stderr, @wait_thr = Open3.popen3(cmd, pgroup: 0)
    @logger.info "Started Playwright browser process with PID #{@wait_thr.pid}"

    output = ""
    status_code = nil

    begin
      Timeout.timeout(30) do  # wait up to 30 seconds for the response
        while line = stdout.gets
          output += line
          if output.include?('status_code')
            begin
              data = JSON.parse(output.strip)
              status_code = data['status_code']
              break
            rescue JSON::ParserError
              # continue reading if not complete JSON
            end
          end
        end
      end
    rescue Timeout::Error, IOError => e
      @logger.error "Error: #{e.message} (#{e.class})"
      close
      return { error: "Timeout waiting for status code or IO error: #{e.message} (#{e.class})" }
    end

    # If we got the status code, return it
    if status_code
      { "browser_pid": @wait_thr.pid, "status_code": status_code }
    else
      # If process finished without status, check exit status
      close
      begin
        exit_status = @wait_thr.value
        if exit_status.success?
          { error: "Unexpected success without status code" }
        else
          { error: "Process failed with exit code #{exit_status.exitstatus}: #{output}#{stderr.read}" }
        end
      rescue Errno::ECHILD
        { error: "Process was killed" }
      end
    end
  end

  def close
    return unless @wait_thr

    @logger.info "Closing Playwright browser process with PID #{@wait_thr.pid}"
    child_pid = closest_child_pid(@wait_thr.pid)
    @logger.info "Child Playwright process PID: #{child_pid}"
    kill_process(@wait_thr.pid)
    if child_pid
      @logger.info "Also killing child Playwright process with PID #{child_pid}"
      kill_process(child_pid)
    end
    @wait_thr = nil
  end

  private

  def kill_process(pid)
    begin
      Process.kill(0, pid)
    rescue Errno::ESRCH
      @logger.debug "Process #{pid} is not running"
      return
    end

    Process.kill('TERM', pid) rescue nil
    sleep 0.1  # Give it a moment to respond to TERM
    begin
      Process.kill(0, pid)
      # If we reach here, process is still alive, try SIGINT
      @logger.debug "Process #{pid} still alive after TERM, sending SIGINT"
      Process.kill('INT', pid) rescue nil
      sleep 2
      begin
        Process.kill(0, pid)
        # Still alive, force kill
        @logger.debug "Process #{pid} still alive after INT, sending SIGKILL"
        Process.kill('KILL', pid) rescue nil
      rescue Errno::ESRCH
        @logger.debug "Process #{pid} killed with SIGKILL"
      end
    rescue Errno::ESRCH
      @logger.debug "Process #{pid} killed with TERM"
    end
  end

  private

  def closest_child_pid(parent_pid)
    # Use ps command to find child processes, more portable than reading /proc
    ps_cmd = "ps -eo pid,ppid | grep ' #{parent_pid}' | awk '{print $1}'"
    ps_output = `#{ps_cmd}`
    child_pids = ps_output.split.map(&:to_i).reject(&:zero?)
    # Return the child with the smallest PID (first spawned)
    child_pids.min
  end
end
