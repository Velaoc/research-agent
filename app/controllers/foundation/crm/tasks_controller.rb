# frozen_string_literal: true

module Foundation
  module Crm
    class TasksController < BaseController
      before_action :set_task, only: %i[show edit update destroy complete]

      def index
        scope = crm_scope(Task).includes(:assignee, :creator).ordered
        scope = scope.search(params[:q]) if params[:q].present?
        status = params[:status].to_s
        if status.presence_in(Task::STATUSES)
          scope = scope.with_status(status)
        elsif status != "all" && params[:all] != "1"
          scope = scope.open_tasks
        end
        scope = scope.assigned_to(current_user) if params[:mine] == "1"
        @tasks = paginate(scope)
      end

      def show; end

      def new
        @task = crm_scope(Task).new(assignee: current_user, status: "open")
        apply_taskable_from_params(@task)
        @members = organization_members
      end

      def create
        @task = crm_scope(Task).new(task_params)
        @task.organization = @organization
        @task.creator = current_user
        if @task.save
          redirect_to task_redirect_path(@task), notice: "Task created."
        else
          @members = organization_members
          render :new, status: :unprocessable_content
        end
      end

      def edit
        @members = organization_members
      end

      def update
        if @task.update(task_params.except(:taskable_type, :taskable_id))
          redirect_to crm_task_path(@task), notice: "Task updated."
        else
          @members = organization_members
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        @task.destroy!
        redirect_to crm_tasks_path, notice: "Task deleted."
      end

      def complete
        @task.complete!(actor: current_user)
        redirect_back fallback_location: crm_task_path(@task), notice: "Task completed."
      end

      private

      def set_task
        @task = find_crm!(Task)
      end

      def task_params
        permitted = params.require(:task).permit(
          :title, :description, :due_on, :status, :assignee_id,
          :taskable_type, :taskable_id
        )
        if permitted.key?(:assignee_id)
          raw = permitted[:assignee_id].presence
          permitted[:assignee_id] = raw && organization_members.where(id: raw).pick(:id)
        end
        if permitted[:taskable_type].present? && permitted[:taskable_id].present?
          type = permitted[:taskable_type].to_s
          model = Task.taskable_model_for(type)
          if model
            id = crm_scope(model).where(id: permitted[:taskable_id]).pick(:id)
            permitted[:taskable_type] = id ? type : nil
            permitted[:taskable_id] = id
          else
            permitted[:taskable_type] = nil
            permitted[:taskable_id] = nil
          end
        end
        if permitted[:status].present? && permitted[:status].to_s.presence_in(Task::STATUSES).nil?
          permitted.delete(:status)
        end
        permitted
      end

      def apply_taskable_from_params(task)
        model = Task.taskable_model_for(params[:taskable_type])
        return unless model && params[:taskable_id].present?

        record = crm_scope(model).find_by(id: params[:taskable_id])
        task.taskable = record if record
      end

      def task_redirect_path(task)
        return crm_task_path(task) unless task.taskable

        case task.taskable
        when Contact then crm_contact_path(task.taskable)
        when Company then crm_company_path(task.taskable)
        when Lead then crm_lead_path(task.taskable)
        when Opportunity then crm_opportunity_path(task.taskable)
        else crm_task_path(task)
        end
      end
    end
  end
end
