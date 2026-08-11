# frozen_string_literal: true

module Foundation
  module Crm
    class TagsController < BaseController
      def index
        @tags = crm_scope(Tag).ordered
        @tag = crm_scope(Tag).new
      end

      def create
        @tag = crm_scope(Tag).new(tag_params)
        @tag.organization = @organization
        if @tag.save
          redirect_to crm_tags_path, notice: "Tag created."
        else
          @tags = crm_scope(Tag).ordered
          render :index, status: :unprocessable_content
        end
      end

      def destroy
        tag = find_crm!(Tag)
        tag.destroy!
        redirect_to crm_tags_path, notice: "Tag deleted."
      end

      private

      def tag_params
        params.require(:tag).permit(:name)
      end
    end
  end
end
