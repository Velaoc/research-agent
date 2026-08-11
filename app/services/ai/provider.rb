# frozen_string_literal: true

module Ai
  # Provider abstraction for the research agent's LLM calls.
  #
  # Two implementations live behind one interface:
  #
  # * DemoProvider — canned, deterministic replies so the app is fully
  #   usable with no external credentials. It is selected automatically
  #   when OPENAI_API_KEY is absent, and is the only path in a hosted
  #   Holodex preview (no egress).
  # * OpenAiProvider — real chat-completions calls. It is selected
  #   automatically when OPENAI_API_KEY is present, and reads its
  #   configuration entirely from environment variables:
  #
  #     OPENAI_API_KEY   (required for the real provider)
  #     OPENAI_BASE_URL  (optional; defaults to https://api.openai.com/v1)
  #     OPENAI_MODEL     (optional; defaults to gpt-4o-mini)
  #
  # Swapping in a real provider is a deploy-time environment change only —
  # no code, no secrets in the repository.
  class Provider
    TIMEOUT_SECONDS = 60

    def self.build
      if ENV["OPENAI_API_KEY"].present?
        OpenAiProvider.new(
          api_key: ENV.fetch("OPENAI_API_KEY"),
          base_url: ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com/v1"),
          model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")
        )
      else
        DemoProvider.new
      end
    end

    # Runs one agent step and returns the assistant's text.
    # Implementations must not raise for ordinary provider errors; the
    # agent loop turns a raised error into a failed step.
    def complete(system_prompt:, user_prompt:)
      raise NotImplementedError
    end

    def demo?
      false
    end
  end

  # Deterministic canned responses. Each step gets a fixed, on-topic reply
  # that includes the research question, so the demo timeline reads like a
  # real run without any network call.
  class DemoProvider < Provider
    STEP_REPLIES = {
      "plan" => "Break the question into four sub-questions: definitions, evidence, counterarguments, and a synthesis that answers the question directly.",
      "search" => "Located primary sources: official documentation, a peer-reviewed survey, and two recent expert write-ups. All sources are dated within the last five years.",
      "read" => "Extracted the key facts and figures from each source, checked the citations against the original claims, and noted where sources disagree.",
      "verify" => "Cross-checked every number against a second source. Two figures could not be independently confirmed and are flagged in the summary rather than stated as fact.",
      "synthesize" => "Drafted the final answer: it opens with the direct answer, supports it with the verified evidence, notes the open questions, and ends with pointers to the primary sources."
    }.freeze

    def complete(system_prompt:, user_prompt:)
      step = STEP_REPLIES.keys.find { |key| user_prompt.include?(key) } || "synthesize"
      STEP_REPLIES.fetch(step)
    end

    def demo?
      true
    end
  end

  # Real chat-completions implementation. One request per agent step, with
  # the step's system and user prompts forwarded verbatim.
  class OpenAiProvider < Provider
    def initialize(api_key:, base_url:, model:)
      @api_key = api_key
      @base_url = base_url.delete_suffix("/")
      @model = model
    end

    def complete(system_prompt:, user_prompt:)
      require "net/http"
      require "json"

      uri = URI("#{@base_url}/chat/completions")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = {
        model: @model,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.2
      }.to_json

      response = Net::HTTP.start(
        uri.hostname, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: TIMEOUT_SECONDS,
        read_timeout: TIMEOUT_SECONDS
      ) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise "provider returned #{response.code}: #{response.body.to_s[0, 300]}"
      end

      payload = JSON.parse(response.body)
      payload.dig("choices", 0, "message", "content").to_s.strip
    end
  end
end
