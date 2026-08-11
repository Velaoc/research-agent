# frozen_string_literal: true

module Foundation
  module Native
    class BaseController < ApplicationController
      include Foundation::NativeShell
    end
  end
end
