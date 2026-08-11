# frozen_string_literal: true

module Foundation
  module Crm
    class PipelinesController < BaseController
      before_action :ensure_default_pipeline!, only: :index
      before_action :set_pipeline, only: %i[show edit update destroy]

      def index
        @pipelines = crm_scope(Pipeline).includes(:stages).ordered
      end

      def show
        @stages = @pipeline.stages.ordered
        @opportunities = crm_scope(Opportunity).where(pipeline: @pipeline).includes(:pipeline_stage, :owner).ordered.limit(100)
      end

      def new
        @pipeline = crm_scope(Pipeline).new
      end

      def create
        @pipeline = crm_scope(Pipeline).new(pipeline_params)
        @pipeline.organization = @organization
        if @pipeline.save
          redirect_to crm_pipeline_path(@pipeline), notice: "Pipeline created."
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit; end

      def update
        if @pipeline.update(pipeline_params)
          redirect_to crm_pipeline_path(@pipeline), notice: "Pipeline updated."
        else
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        if @pipeline.opportunities.exists?
          redirect_to crm_pipeline_path(@pipeline), alert: "Move or delete opportunities before removing this pipeline."
        else
          @pipeline.destroy!
          redirect_to crm_pipelines_path, notice: "Pipeline deleted."
        end
      end

      private

      def set_pipeline
        @pipeline = find_crm!(Pipeline)
      end

      def pipeline_params
        params.require(:pipeline).permit(:name, :position)
      end
    end
  end
end
