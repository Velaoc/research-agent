# frozen_string_literal: true

class ResearchRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_run, only: :show

  def index
    @runs = current_user.research_runs.recent.includes(:steps)
  end

  def new
    @run = current_user.research_runs.new
  end

  def create
    @run = current_user.research_runs.new(run_params)
    if @run.save
      Ai::ResearchAgent.new(run: @run).call
      redirect_to research_run_path(@run), notice: "Research complete."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @steps = @run.steps.ordered
  end

  private

  def set_run
    @run = current_user.research_runs.find(params[:id])
  end

  def run_params
    params.require(:research_run).permit(:question)
  end
end
