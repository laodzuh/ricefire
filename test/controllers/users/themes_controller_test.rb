require "test_helper"

class Users::ThemesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show lists the bundled themes" do
    get user_theme_url

    assert_response :success
    assert_select ".theme-picker__option", count: Theme.bundled.size + 1
    assert_select "style#theme_style:not([data-mode])"
  end

  test "picking a theme" do
    patch user_theme_url, params: { user: { theme: "gruvbox" } }

    assert_redirected_to user_theme_url
    assert_equal "gruvbox", users(:david).reload.theme

    get user_profile_url
    assert_select "style#theme_style[data-mode=dark]", text: /--lch-white/
    assert_select "meta[name=theme-color][content=?]", Theme.find("gruvbox").colors["background"]
  end

  test "back to Campfire's own colors" do
    users(:david).update!(theme: "nord")

    patch user_theme_url, params: { user: { theme: "" } }

    assert_nil users(:david).reload.theme
  end

  test "a theme that doesn't exist" do
    patch user_theme_url, params: { user: { theme: "nope" } }

    assert_redirected_to user_theme_url
    assert_equal "That theme isn't available.", flash[:alert]
    assert_nil users(:david).reload.theme
  end

  test "picking a theme updates open pages" do
    assert_turbo_stream_broadcasts [ users(:david), :theme ] do
      patch user_theme_url, params: { user: { theme: "nord" } }
    end
  end

  test "setting up Omarchy sync shows the key" do
    get user_theme_url
    assert_select "textarea#theme_sync_config", count: 0

    post user_theme_sync_token_url
    assert_redirected_to user_theme_url(anchor: "omarchy")

    token = users(:david).reload.theme_sync_token
    assert token.present?

    get user_theme_url
    assert_select "textarea#theme_sync_config", text: /CAMPFIRE_THEME_KEY=#{token}/
    assert_select "textarea#theme_sync_hook", text: /theme_sync/
  end
end
