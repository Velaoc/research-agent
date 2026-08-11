# frozen_string_literal: true

module Foundation
  module Crm
    class CompaniesController < BaseController
      before_action :set_company, only: %i[show edit update destroy]

      def index
        scope = crm_scope(Company).ordered
        scope = scope.search(params[:q]) if params[:q].present?
        @companies = paginate(scope)
      end

      def show
        @contacts = crm_scope(Contact).where(company: @company).ordered.limit(50)
        load_timeline(@company)
      end

      def new
        @company = crm_scope(Company).new
      end

      def create
        @company = crm_scope(Company).new(company_params)
        @company.organization = @organization
        if @company.save
          record_created(@company)
          redirect_to crm_company_path(@company), notice: "Company created."
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit; end

      def update
        if @company.update(company_params)
          redirect_to crm_company_path(@company), notice: "Company updated."
        else
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        @company.destroy!
        redirect_to crm_companies_path, notice: "Company deleted."
      end

      private

      def set_company
        @company = find_crm!(Company)
      end

      def company_params
        params.require(:company).permit(:name, :domain, :website, :phone, :industry)
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
