# frozen_string_literal: true

require "test_helper"

class DevicesSettingsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery"
  # Unknown product tokens are allowed by allow_browser :modern and stay
  # distinguishable in the sessions registry (same pattern as admin tests).
  ACTOR_UA = "DevicesActor/1.0"
  OTHER_UA = "DevicesOther/1.0"
  EXTRA_UA = "DevicesExtra/1.0"
  VICTIM_UA = "DevicesVictim/1.0"
  TARGET_UA = "DevicesTarget/1.0"

  setup do
    @user = users(:confirmed)
    @other = users(:admin)
  end

  def sign_in_as(user, password: PASSWORD, user_agent: ACTOR_UA)
    delete destroy_user_session_path
    post user_session_path,
      params: { user: { email: user.email, password: password } },
      headers: { "User-Agent" => user_agent }
  end

  test "devices page requires sign-in" do
    get settings_sessions_root_path
    assert_redirected_to new_user_session_path
  end

  test "devices page lists only current user live sessions" do
    other_browser = open_session
    other_browser.post user_session_path,
      params: { user: { email: @other.email, password: PASSWORD } },
      headers: { "User-Agent" => VICTIM_UA }
    other_browser.assert_response :redirect
    other_session = @other.sessions.live.find_by!(user_agent: VICTIM_UA)

    sign_in_as(@user)
    get settings_sessions_root_path
    assert_response :success
    assert_select "h1", text: "Your devices"
    assert_select "form[action=?]", settings_sessions_session_path(other_session), count: 0
  end

  test "current session is marked and not revocable" do
    sign_in_as(@user)
    get settings_sessions_root_path
    assert_response :success
    assert_select "span", text: "This device"

    current = @user.sessions.live.find_by!(user_agent: ACTOR_UA)
    grant_reauthentication!
    delete settings_sessions_session_path(current)
    assert_redirected_to settings_sessions_root_path
    assert_nil current.reload.ended_at
  end

  test "revoke one ends that row immediately" do
    sign_in_as(@user)
    other_browser = open_session
    other_browser.post user_session_path,
      params: { user: { email: @user.email, password: PASSWORD } },
      headers: { "User-Agent" => OTHER_UA }
    other_browser.assert_response :redirect

    target = @user.sessions.live.find_by!(user_agent: OTHER_UA)
    grant_reauthentication!
    delete settings_sessions_session_path(target)
    assert_redirected_to settings_sessions_root_path
    assert_predicate target.reload, :ended?

    other_browser.get settings_sessions_root_path
    other_browser.assert_redirected_to new_user_session_path

    get settings_sessions_root_path
    assert_response :success
  end

  test "revoke others keeps current only" do
    sign_in_as(@user)
    2.times do |i|
      browser = open_session
      browser.post user_session_path,
        params: { user: { email: @user.email, password: PASSWORD } },
        headers: { "User-Agent" => "#{EXTRA_UA}-#{i}" }
      browser.assert_response :redirect
    end

    current = @user.sessions.live.find_by!(user_agent: ACTOR_UA)
    assert_operator @user.sessions.live.count, :>=, 3

    grant_reauthentication!
    delete settings_sessions_others_path
    assert_redirected_to settings_sessions_root_path
    assert_equal [ current.id ], @user.sessions.live.pluck(:id)
  end

  test "user A cannot revoke user B session" do
    victim_browser = open_session
    victim_browser.post user_session_path,
      params: { user: { email: @other.email, password: PASSWORD } },
      headers: { "User-Agent" => VICTIM_UA }
    victim_browser.assert_response :redirect
    victim = @other.sessions.live.find_by!(user_agent: VICTIM_UA)
    assert_nil victim.ended_at

    sign_in_as(@user)
    grant_reauthentication!

    delete settings_sessions_session_path(victim)
    assert_response :not_found
    assert_nil victim.reload.ended_at
  end

  test "list never embeds other users ids" do
    victim_browser = open_session
    victim_browser.post user_session_path,
      params: { user: { email: @other.email, password: PASSWORD } },
      headers: { "User-Agent" => VICTIM_UA }
    victim_browser.assert_response :redirect
    secret_id = @other.sessions.live.find_by!(user_agent: VICTIM_UA).id

    sign_in_as(@user)
    get settings_sessions_root_path
    assert_response :success
    assert_select "form[action=?]", settings_sessions_session_path(secret_id), count: 0
  end

  test "device revoke blocked without window" do
    sign_in_as(@user)
    other = open_session
    other.post user_session_path,
      params: { user: { email: @user.email, password: PASSWORD } },
      headers: { "User-Agent" => TARGET_UA }
    other.assert_response :redirect
    target = @user.sessions.live.find_by!(user_agent: TARGET_UA)

    delete settings_sessions_session_path(target)
    assert_redirected_to new_reauthentication_path
    assert_nil target.reload.ended_at
  end

  test "device revoke allowed with window" do
    sign_in_as(@user)
    other = open_session
    other.post user_session_path,
      params: { user: { email: @user.email, password: PASSWORD } },
      headers: { "User-Agent" => TARGET_UA }
    other.assert_response :redirect
    target = @user.sessions.live.find_by!(user_agent: TARGET_UA)

    grant_reauthentication!
    delete settings_sessions_session_path(target)
    assert_predicate target.reload, :ended?
  end

  test "devices page shows device name and last seen without forcing location" do
    sign_in_as(@user)
    get settings_sessions_root_path
    assert_response :success
    assert_match(/Last seen/, response.body)
    assert_no_match(/[\u{1F1E6}-\u{1F1FF}]{2}/, response.body)
  end
end
