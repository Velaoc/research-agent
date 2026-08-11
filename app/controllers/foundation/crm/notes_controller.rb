# frozen_string_literal: true

module Foundation
  module Crm
    class NotesController < BaseController
      def create
        notable = find_notable!
        note = crm_scope(Note).new(note_params)
        note.organization = @organization
        note.author = current_user
        note.notable = notable
        if note.save
          redirect_back fallback_location: notable_path(notable), notice: "Note added."
        else
          redirect_back fallback_location: notable_path(notable), alert: note.errors.full_messages.to_sentence.presence || "Could not save note."
        end
      end

      def destroy
        note = find_crm!(Note)
        notable = note.notable
        note.destroy!
        redirect_back fallback_location: notable ? notable_path(notable) : crm_root_path, notice: "Note deleted."
      end

      private

      def note_params
        params.require(:note).permit(:body)
      end

      def find_notable!
        model = Note.notable_model_for(params[:notable_type])
        raise ActiveRecord::RecordNotFound unless model && params[:notable_id].present?

        crm_scope(model).find(params[:notable_id])
      end

      def notable_path(notable)
        case notable
        when Contact then crm_contact_path(notable)
        when Company then crm_company_path(notable)
        when Lead then crm_lead_path(notable)
        when Opportunity then crm_opportunity_path(notable)
        else crm_root_path
        end
      end
    end
  end
end
