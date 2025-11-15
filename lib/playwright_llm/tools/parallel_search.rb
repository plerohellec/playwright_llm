require 'net/http'
require 'uri'
require 'json'

class PlaywrightLLM::Tools::ParallelSearch < RubyLLM::Tool
  description "Searches the web using the Parallel.ai search API and returns the JSON results. The API key must be provided in ENV['PARALLEL_API_KEY']."
  param :query, desc: "The search text to send to the Parallel.ai search API", required: true

  def execute(query:)
    logger = PlaywrightLLM.logger

    begin
      logger.info "============================"
      logger.info "Parallel.ai search — query: #{query.inspect}"

      api_key = ENV['PARALLEL_API_KEY']
      unless api_key && !api_key.empty?
        logger.error "Missing PARALLEL_API_KEY environment variable"
        return { error: "PARALLEL_API_KEY environment variable is not set" }
      end

      uri = URI.parse('https://api.parallel.ai/v1beta/search')
      headers = {
        'Content-Type' => 'application/json',
        'x-api-key' => api_key,
        'parallel-beta' => 'search-extract-2025-10-10'
      }

      body = {
        mode: 'one-shot',
        search_queries: nil,
        max_results: 10,
        objective: query,
        # excerpts: { max_chars_per_result: 2000 }
        max_chars_per_result: 2000
      }

      logger.debug "Parallel.search POST #{uri} with body=#{body.inspect}"

      # Use Net::HTTP.post to keep the call simple and consistent with stdlib.
      resp = Net::HTTP.post(uri, body.to_json, headers)

      if resp.is_a?(Net::HTTPSuccess)
        parsed = JSON.parse(resp.body)
        logger.info "Parallel.ai search successful — results count: #{(parsed['results'] || []).length rescue 'unknown'}"
        logger.info "============================"
        parsed
      else
        logger.error "Parallel.ai search failed: #{resp.code} #{resp.message} — #{resp.body}"
        { error: "Parallel.ai search failed: #{resp.code} #{resp.message}", response: resp.body }
      end
    rescue => e
      logger.error "Parallel search error: #{e.class} - #{e.message}"
      { error: "Parallel search failed: #{e.message}" }
    end
  end
end
