# Playwright::LLM

Playwright::LLM is a Ruby helper that combines the conversational capabilities of `RubyLLM` with a Playwright-powered Chromium browser so you can browse, click, and scrape websites through the same tooling used by large language models.

## Overview

- **Persistent Playwright bridge.** `PlaywrightLLM::Browser` starts the Node.js launcher in `js/launcher.js`, keeps Chromium open on CDP port 9222, and exposes environment variables for headless mode and user agents.
- **Reusable browser tools.** The Ruby tools in `lib/playwright_llm/tools/*` wrap the scripts in `js/tools/`, letting a model call `Navigate`, `SlimHtml`, `Click`, `FullHtml`, or even the generic `Executor` without writing JavaScript.
- **LLM-centric agent.** `PlaywrightLLM::Agent` wires up a `RubyLLM::Chat`, registers the browser tools, normalizes garbled tool names, and exposes a simple `launch`, `ask`, and `close` lifecycle.

## Requirements

- **Ruby** `>= 3.2.0` (see `playwright_llm.gemspec`).
- **Node.js** (Playwright 1.56.1 prefers Node 18+).
- **Playwright dependencies.** Run `npm install` and `npx playwright install chromium` so the JavaScript helpers can launch Chromium.
- **API keys.** Provide `OPENROUTER_API_KEY` and/or `GEMINI_API_KEY` via ENV so the default CLI content providers can talk to OpenRouter or Gemini.
  If you also want to use the Parallel.ai web search tool, set `PARALLEL_API_KEY` in your environment. This key is used by the `PlaywrightLLM::Tools::ParallelSearch` tool to call `https://api.parallel.ai/v1beta/search`.
	You must add this tool to the agent manually.

## Installation

```bash
bundle install        # or ./bin/setup
npm install          # pulls in Playwright
npx playwright install chromium  # downloads the browser binaries
```

## Configuration

```ruby
require "logger"
require "ruby_llm"
require "playwright_llm"

logger = Logger.new($stdout)
logger.level = Logger::DEBUG

RubyLLM.configure do |config|
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.default_model = "google/gemini-2.5-flash-preview-09-2025"
  config.use_new_acts_as = true
  config.logger = logger
end

PlaywrightLLM.configure do |config|
  config.logger = logger
  config.headless = true
  config.user_agent = ENV["PLAYWRIGHT_LLM_USER_AGENT"]
end
```

- `logger` defaults to an `INFO` logger printing to STDOUT; replace it with your own if you need `DEBUG` or file logging.
- `headless` defaults to `true`; pass `false` or use `--no-headless` in the CLI to open a visible browser.
- `user_agent` is optional; if set, it is forwarded to the Node launcher (`PLAYWRIGHT_LLM_USER_AGENT`).

## Using the Agent

```ruby
agent = PlaywrightLLM::Agent.from_provider_model(
  provider: "openrouter",
  model: "google/gemini-2.5-flash-preview-09-2025"
)
agent.launch
response = agent.ask("Navigate to https://example.com and summarize the header")
puts response.content
agent.close
```

- Always call `agent.launch` before asking so the CDP browser is running.
- Use `agent.with_instructions(<<~INSTRUCTIONS)` to steer the tool usage before you `launch`.
- Wrap the agent in a `begin`/`ensure` block so the background browser process is killed even when the prompt raises.

### Tools

| Tool | Description |
| --- | --- |
| `PlaywrightLLM::Tools::Navigate` | Navigates to a URL and logs the HTTP status code. |
| `PlaywrightLLM::Tools::SlimHtml` | Returns cleaned HTML split in 80 000-character chunks (`page:` selects the chunk). |
| `PlaywrightLLM::Tools::Click` | Clicks a CSS selector, waits for `networkidle`, and reports the resulting URL/status. |
| `PlaywrightLLM::Tools::FullHtml` | Extracts the full HTML inside a selector (bodies are blocked to keep payloads manageable). |
| `PlaywrightLLM::Tools::ParallelSearch` | Calls the Parallel.ai search API with a single search query and returns structured JSON results. Not included by default.|

All tools depend on the Chromium session started by `js/launcher.js`, which the Ruby browser process creates before the tool scripts run.

If you already maintain a `RubyLLM::Chat` instance—for example, to reuse streaming callbacks—init the agent with `PlaywrightLLM::Agent.from_chat(rubyllm_chat: chat)` so it registers the browser tools on your existing chat client.

## JavaScript helpers

- `js/launcher.js` launches Chromium via Playwright, honors `PLAYWRIGHT_LLM_HEADLESS` and `PLAYWRIGHT_LLM_USER_AGENT`, and keeps the browser alive so Ruby tools can connect over `localhost:9222`.
- The scripts in `js/tools/` connect with `chromium.connectOverCDP('http://localhost:9222')`, reuse the first context/page, and log helpful `PLWLLM_LOG:` lines that the Ruby helpers forward to the configured `Logger`.
- `js/slim_html.js` encapsulates the DOM cleanup, pagination, and ID helpers used by the Ruby `SlimHtml` tool.

## CLI

### `bin/one_shot.rb`

- Run `bundle exec ruby bin/one_shot.rb [options] PROMPT` for a single-turn request.
- Options:
  - `--provider PROVIDER` (default: `openrouter`).
  - `--model MODEL` (default: `google/gemini-2.5-flash-preview-09-2025`).
  - `--[no-]headless` toggles the browser mode.
  - `--user-agent USER_AGENT` overrides the browser identity.
- Honors `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, and `PLAYWRIGHT_LLM_USER_AGENT` environment variables.
- Logs token counts (`input_tokens`, `output_tokens`, `cached_tokens`) when your logger is in `DEBUG`.

### `bin/playwright-chat.rb`

- Starts an interactive chat REPL, letting you craft multi-line prompts (finish with an empty line) and type `exit`/`quit` to end.
- Accepts the same `--[no-]headless` and `--user-agent` flags and picks sensible defaults if they are omitted.
- The CLI currently buffers replies until the model finishes; enable the streaming branch manually if you need chunked output.

## Development

- Run `bin/setup` (= `bundle install`).
- Use `bin/console` to experiment interactively; bundler and Playwright are already wired in.
- Update `lib/playwright_llm/version.rb` before a release.
- Publish with `bundle exec rake release` (builds the gem, tags it, and pushes to RubyGems). Install locally with `bundle exec rake install`.
- There are no automated tests yet—if you add some, explain how to run them in this README.

## License

MIT (see `LICENSE.txt`).
