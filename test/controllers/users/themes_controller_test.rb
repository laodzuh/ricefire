require "test_helper"

class Users::ThemesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "the settings page lists the bundled themes" do
    get edit_account_url

    assert_response :success
    assert_select "#theme .theme-picker__option", count: Theme.bundled.size + 1
    assert_select "style#theme_style:not([data-mode])"
  end

  test "members who aren't admins get the picker too" do
    sign_in :kevin
    assert_not users(:kevin).administrator?

    get edit_account_url

    assert_response :success
    assert_select "#theme .theme-picker__option", count: Theme.bundled.size + 1
    assert_select "#omarchy"
  end

  test "picking a theme swaps its styles in place" do
    patch user_theme_url, params: { user: { theme: "gruvbox" } }, as: :turbo_stream

    assert_response :success
    assert_equal "gruvbox", users(:david).reload.theme
    assert_turbo_stream action: :replace, target: "theme_style" do
      assert_select "template style[data-mode=dark][data-turbo-track=reload]", text: /--lch-white/
    end
  end

  test "picking a theme without Turbo" do
    patch user_theme_url, params: { user: { theme: "gruvbox" } }

    assert_redirected_to edit_account_url(anchor: "theme")

    get edit_account_url
    assert_select "style#theme_style[data-mode=dark][data-turbo-track=reload]", text: /--lch-white/
    assert_select "meta[name=theme-color][content=?]", Theme.find("gruvbox").colors["background"]
  end

  test "back to Campfire's own colors" do
    users(:david).update!(theme: "nord")

    patch user_theme_url, params: { user: { theme: "" } }, as: :turbo_stream

    assert_nil users(:david).reload.theme
    assert_turbo_stream action: :replace, target: "theme_style"
  end

  test "a theme that doesn't exist" do
    patch user_theme_url, params: { user: { theme: "nope" } }

    assert_redirected_to edit_account_url(anchor: "theme")
    assert_equal "That theme isn't available.", flash[:alert]
    assert_nil users(:david).reload.theme
  end

  test "picking a theme updates other open pages" do
    assert_turbo_stream_broadcasts [ users(:david), :theme ] do
      patch user_theme_url, params: { user: { theme: "nord" } }, as: :turbo_stream
    end
  end

  test "setting up Omarchy sync shows the key in place" do
    get edit_account_url
    assert_select "#omarchy textarea#theme_sync_config", count: 0

    post user_theme_sync_token_url, as: :turbo_stream
    assert_response :success

    token = users(:david).reload.theme_sync_token
    assert token.present?
    assert_turbo_stream action: :replace, target: "omarchy" do
      assert_select "template details[open] textarea#theme_sync_config", text: /CAMPFIRE_THEME_KEY=#{token}/
      assert_select "template textarea#theme_sync_hook", text: /theme_sync/
    end

    get edit_account_url
    assert_select "#omarchy textarea#theme_sync_config", text: /CAMPFIRE_THEME_KEY=#{token}/
  end
end
