# frozen_string_literal: true

module Foundation
  module Crm
    class ContactsController < BaseController
      before_action :set_contact, only: %i[show edit update destroy]

      def index
        scope = crm_scope(Contact).includes(:company, :owner).ordered
        scope = scope.search(params[:q]) if params[:q].present?
        scope = scope.owned_by(current_user) if params[:mine] == "1"
        @contacts = paginate(scope)
      end

      def show
        load_timeline(@contact)
      end

      def new
        @contact = crm_scope(Contact).new(owner: current_user)
        load_form_collections
      end

      def create
        @contact = crm_scope(Contact).new(contact_params)
        @contact.organization = @organization
        if @contact.save
          record_created(@contact)
          redirect_to crm_contact_path(@contact), notice: "Contact created."
        else
          load_form_collections
          render :new, status: :unprocessable_content
        end
      end

      def edit
        load_form_collections
      end

      def update
        if @contact.update(contact_params)
          redirect_to crm_contact_path(@contact), notice: "Contact updated."
        else
          load_form_collections
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        @contact.destroy!
        redirect_to crm_contacts_path, notice: "Contact deleted."
      end

      private

      def set_contact
        @contact = find_crm!(Contact)
      end

      def contact_params
        permitted = params.require(:contact).permit(
          :first_name, :last_name, :email, :phone, :title, :company_id, :owner_id
        )
        sanitize_org_refs!(permitted, company_id: Company, owner_id: :member)
        permitted
      end

      def sanitize_org_refs!(permitted, company_id: nil, owner_id: nil)
        if company_id && permitted[:company_id].present?
          permitted[:company_id] = crm_scope(company_id).where(id: permitted[:company_id]).pick(:id)
        end
        if owner_id == :member && permitted.key?(:owner_id)
          raw = permitted[:owner_id].presence
          permitted[:owner_id] = raw && organization_members.where(id: raw).pick(:id)
        end
      end

      def load_form_collections
        @companies = crm_scope(Company).ordered
        @members = organization_members
      end

      def load_timeline(record)
        @notes = crm_scope(Note).where(notable: record).includes(:author).ordered.limit(50)
        @tasks = crm_scope(Task).where(taskable: record).ordered.limit(50)
        @activities = crm_scope(Activity).for_trackable(record).includes(:actor).ordered.limit(50)
        @note = crm_scope(Note).new(notable: record)
        @task = crm_scope(Task).new(taskable: record, assignee: current_user)
        @members = organization_members
      end
    end
  end
end
