# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  include Devise::Controllers::Rememberable

  # Durable sign-in for Hotwire Native web views (SPEC M14). The shell's
  # WKWebView / Android WebView keeps the Devise session cookie for the
  # process lifetime; rememberable extends that across process death via the
  # remember_user_token cookie. Ordinary browsers keep the explicit checkbox.
  def create
    super do |resource|
      remember_me(resource) if hotwire_native_app?
    end
  end
end
