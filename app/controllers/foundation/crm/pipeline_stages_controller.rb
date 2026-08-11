# frozen_string_literal: true

module Foundation
  module Crm
    class PipelineStagesController < BaseController
      before_action :set_pipeline
      before_action :set_stage, only: %i[edit update destroy]

      def new
        @stage = crm_scope(PipelineStage).new(pipeline: @pipeline, organization: @organization)
      end

      def create
        @stage = crm_scope(PipelineStage).new(stage_params)
        @stage.pipeline = @pipeline
        @stage.organization = @organization
        if @stage.save
          redirect_to crm_pipeline_path(@pipeline), notice: "Stage created."
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit; end

      def update
        if @stage.update(stage_params)
          redirect_to crm_pipeline_path(@pipeline), notice: "Stage updated."
        else
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        if @stage.opportunities.exists?
          redirect_to crm_pipeline_path(@pipeline), alert: "Move opportunities out of this stage first."
        else
          @stage.destroy!
          redirect_to crm_pipeline_path(@pipeline), notice: "Stage deleted."
        end
      end

      private

      def set_pipeline
        @pipeline = find_crm!(Pipeline, params[:pipeline_id])
      end

      def set_stage
        @stage = crm_scope(PipelineStage).where(pipeline: @pipeline).find(params[:id])
      end

      def stage_params
        permitted = params.require(:pipeline_stage).permit(
          :name, :position, :probability, :closed_won, :closed_lost
        )
        permitted[:closed_won] = ActiveModel::Type::Boolean.new.cast(permitted[:closed_won])
        permitted[:closed_lost] = ActiveModel::Type::Boolean.new.cast(permitted[:closed_lost])
        permitted
      end
    end
  end
end
