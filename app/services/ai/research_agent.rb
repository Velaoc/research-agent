# frozen_string_literal: true

module Ai
  # Runs a research question through a fixed step pipeline, recording every
  # step's input, output, status, and duration on the run's timeline.
  #
  # Execution is deliberately inline (no background worker): a demo run
  # completes in a few hundred milliseconds, the client polls the run's
  # status, and the timeline page live-updates. This keeps the agent
  # observable in the Holodex preview without depending on a queue worker.
  class ResearchAgent
    STEPS = %w[plan search read verify synthesize].freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a careful research assistant. You work through questions step by
      step. Be concrete, cite the evidence you rely on, and clearly flag any
      claim you could not verify. Do not invent sources or numbers.
    PROMPT

    def initialize(run:, provider: Ai::Provider.build)
      @run = run
      @provider = provider
    end

    def call
      @run.update!(status: "running", started_at: Time.current)

      STEPS.each_with_index do |step_name, index|
        step = @run.steps.create!(name: step_name, position: index, status: "running", input: step_input(step_name))

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          output = @provider.complete(
            system_prompt: SYSTEM_PROMPT,
            user_prompt: step_input(step_name)
          )
          step.update!(status: "complete", output: output)
        rescue StandardError => e
          step.update!(status: "failed", output: "Step failed: #{e.class}: #{e.message}")
          @run.update!(status: "failed", finished_at: Time.current, summary: "Failed during the #{step_name} step.")
          return @run
        ensure
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          step.update!(duration_ms: elapsed_ms) if step.persisted?
        end

        # Small pause so the timeline visibly progresses in the demo.
        sleep 0.4
      end

      @run.update!(
        status: "complete",
        finished_at: Time.current,
        summary: summary_text
      )
      @run
    end

    private

    def step_input(step_name)
      case step_name
      when "plan"
        "Plan the research approach for: #{@run.question}"
      when "search"
        "List the sources you would consult for: #{@run.question}"
      when "read"
        "Summarize what the sources say about: #{@run.question}"
      when "verify"
        "Check which claims about #{@run.question} are verified by multiple sources."
      when "synthesize"
        "Write the final answer to: #{@run.question}"
      end
    end

    def summary_text
      latest = @run.steps.complete.order(position: :desc).first
      latest&.output.to_s
    end
  end
end
