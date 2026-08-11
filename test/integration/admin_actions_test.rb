require "test_helper"

class AdminActionsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery"

  setup do
    @admin = users(:admin)
    @target = users(:confirmed)
    @organization = Organizations::Organization.create!(name: "Admin Action Lab")
    Organizations::Membership.create!(organization: @organization, user: @target, role: "owner")
    sign_in_as(@admin)
  end

  test "lock and unlock use Devise APIs and self-lock fails closed" do
    post lock_madmin_user_path(@target)
    assert_redirected_to madmin_user_path(@target)
    assert_predicate @target.reload, :access_locked?

    post unlock_madmin_user_path(@target)
    assert_redirected_to madmin_user_path(@target)
    assert_not_predicate @target.reload, :access_locked?

    post lock_madmin_user_path(@admin)
    assert_redirected_to madmin_user_path(@admin)
    assert_not_predicate @admin.reload, :access_locked?
    assert_match(/cannot lock/, flash[:alert])
  end

  test "plan assignment accepts only configured plans through the M5 owner API" do
    grant_reauthentication!
    post assign_plan_madmin_organization_path(@organization), params: { plan_key: "enterprise" }
    assert_redirected_to madmin_organization_path(@organization)
    assert_equal :enterprise, @organization.reload.current_pricing_plan.key
    assert_equal :assignment, @organization.current_pricing_plan_source

    post assign_plan_madmin_organization_path(@organization), params: { plan_key: "operator-invented" }
    assert_redirected_to madmin_organization_path(@organization)
    assert_equal :enterprise, @organization.reload.current_pricing_plan.key
    assert_match(/configured plan/, flash[:alert])

    post remove_plan_madmin_organization_path(@organization)
    assert_redirected_to madmin_organization_path(@organization)
    assert_equal :free, @organization.reload.current_pricing_plan.key
    assert_equal :default, @organization.current_pricing_plan_source
  end

  test "a single session can be revoked only through its owning row" do
    target_browser = open_session
    target_browser.post user_session_path,
      params: { user: { email: @target.email, password: PASSWORD } },
      headers: { "User-Agent" => "M6 Device Browser/1.0" }
    target_browser.assert_response :redirect

    target_session = @target.sessions.live.find_by!(user_agent: "M6 Device Browser/1.0")
    assert_equal @target, target_session.user
    assert Sessions::Event.logins.exists?(authenticatable: @target, session_id: target_session.id)

    post revoke_madmin_session_path(target_session)
    assert_redirected_to madmin_session_path(target_session)
    assert_predicate target_session.reload, :ended?
    assert_equal "admin_revoked", target_session.ended_reason
    assert Sessions::Event.revocations.exists?(session_id: target_session.id)

    target_browser.get billing_path
    target_browser.assert_redirected_to new_user_session_path
  end

  test "revoke all ends every target session without ending the actor session" do
    two_target_browsers = Array.new(2) do |index|
      open_session.tap do |browser|
        browser.post user_session_path,
          params: { user: { email: @target.email, password: PASSWORD } },
          headers: { "User-Agent" => "Target Device #{index}" }
        browser.assert_response :redirect
      end
    end
    target_ids = @target.sessions.live.pluck(:id)
    actor_ids = @admin.sessions.live.pluck(:id)

    post revoke_all_sessions_madmin_user_path(@target)
    assert_redirected_to madmin_user_path(@target)
    assert_empty Session.live.where(id: target_ids)
    assert_equal actor_ids.sort, @admin.sessions.live.where(id: actor_ids).pluck(:id).sort

    two_target_browsers.each do |browser|
      browser.get billing_path
      browser.assert_redirected_to new_user_session_path
    end
  end

  test "every mutation emits structured audit without request parameters or secrets" do
    grant_reauthentication!
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)

    post assign_plan_madmin_organization_path(@organization), params: {
      plan_key: "pro",
      token: "AUDIT-TOKEN-MUST-NOT-APPEAR"
    }

    event = output.string.lines.find { |line| line.include?(Foundation::Admin::Audit::EVENT_NAME) }
    assert event
    payload = JSON.parse(event[event.index("{")..])
    assert_equal "madmin/organizations#assign_plan", payload.fetch("action")
    assert_equal @admin.id, payload.fetch("actor_id")
    assert_equal @organization.id, payload.fetch("subject_id")
    assert_equal "Organizations::Organization", payload.fetch("subject_type")
    assert_equal "succeeded", payload.fetch("outcome")
    assert payload.fetch("request_id").present?
    assert_equal "POST", payload.fetch("request_method")
    assert_not_includes event, "AUDIT-TOKEN-MUST-NOT-APPEAR"
    assert_not payload.key?("params")
  ensure
    Rails.logger = original_logger
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: PASSWORD } }
    assert_response :redirect
  end
end
