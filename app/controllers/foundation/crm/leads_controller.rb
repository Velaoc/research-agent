# frozen_string_literal: true

module Foundation
  module Crm
    class LeadsController < BaseController
      before_action :set_lead, only: %i[show edit update destroy assign]

      def index
        scope = crm_scope(Lead).includes(:owner, :company).ordered
        scope = scope.search(params[:q]) if params[:q].present?
        scope = scope.with_status(params[:status]) if params[:status].present?
        scope = scope.owned_by(current_user) if params[:mine] == "1"
        @leads = paginate(scope)
      end

      def show
        load_timeline(@lead)
        @members = organization_members
      end

      def new
        @lead = crm_scope(Lead).new(owner: current_user, status: "new")
        load_form_collections
      end

      def create
        @lead = crm_scope(Lead).new(lead_params)
        @lead.organization = @organization
        if @lead.save
          record_created(@lead)
          redirect_to crm_lead_path(@lead), notice: "Lead created."
        else
          load_form_collections
          render :new, status: :unprocessable_content
        end
      end

      def edit
        load_form_collections
      end

      def update
        previous_status = @lead.status
        if @lead.update(lead_params)
          if @lead.status != previous_status
            ActivityRecorder.record!(
              organization: @organization,
              actor: current_user,
              trackable: @lead,
              kind: "status_changed",
              summary: "Status changed from #{previous_status} to #{@lead.status}",
              metadata: { from: previous_status, to: @lead.status }
            )
          end
          redirect_to crm_lead_path(@lead), notice: "Lead updated."
        else
          load_form_collections
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        @lead.destroy!
        redirect_to crm_leads_path, notice: "Lead deleted."
      end

      def assign
        owner_id = params[:owner_id].presence
        owner = owner_id ? organization_members.find_by(id: owner_id) : nil
        if owner_id && owner.nil?
          return redirect_to crm_lead_path(@lead), alert: "Choose a member of this organization."
        end

        @lead.assign_owner!(owner, actor: current_user)
        redirect_to crm_lead_path(@lead), notice: owner ? "Lead assigned." : "Lead unassigned."
      end

      private

      def set_lead
        @lead = find_crm!(Lead)
      end

      def lead_params
        permitted = params.require(:lead).permit(
          :name, :email, :phone, :source, :status, :description,
          :company_id, :contact_id, :owner_id
        )
        if permitted[:company_id].present?
          permitted[:company_id] = crm_scope(Company).where(id: permitted[:company_id]).pick(:id)
        end
        if permitted[:contact_id].present?
          permitted[:contact_id] = crm_scope(Contact).where(id: permitted[:contact_id]).pick(:id)
        end
        if permitted.key?(:owner_id)
          raw = permitted[:owner_id].presence
          permitted[:owner_id] = raw && organization_members.where(id: raw).pick(:id)
        end
        if permitted[:status].present? && permitted[:status].to_s.presence_in(Lead::STATUSES).nil?
          permitted.delete(:status)
        end
        permitted
      end

      def load_form_collections
        @companies = crm_scope(Company).ordered
        @contacts = crm_scope(Contact).ordered.limit(500)
        @members = organization_members
      end

      def load_timeline(record)
        @notes = crm_scope(Note).where(notable: record).includes(:author).ordered.limit(50)
        @tasks = crm_scope(Task).where(taskable: record).ordered.limit(50)
        @activities = crm_scope(Activity).for_trackable(record).includes(:actor).ordered.limit(50)
        @note = crm_scope(Note).new(notable: record)
        @task = crm_scope(Task).new(taskable: record, assignee: current_user)
      end
    end
  end
end
