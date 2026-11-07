require "test_helper"

class Users::ThemeSyncsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    @user.reset_theme_sync_token
    @colors = Theme::DIRECTORY.join("tokyo-night.toml").read
  end

  test "Omarchy sends its theme" do
    sync @colors, name: "my-tokyo"

    assert_response :no_content
    @user.reload
    assert_equal User::Theming::SYNCED, @user.theme
    assert_equal "My Tokyo", @user.current_theme.name
    assert_equal "#1a1b26", @user.current_theme.colors["background"]
  end

  test "sending a theme updates open pages" do
    assert_turbo_stream_broadcasts [ @user, :theme ] do
      sync @colors
    end
  end

  test "the synced theme shows in the picker" do
    sync @colors, name: "tokyo-night"

    sign_in :david
    get edit_account_url
    assert_select ".theme-picker__option", text: /Omarchy: Tokyo Night/
    assert_select "input[type=radio][value=omarchy][checked]"
  end

  test "names are cleaned up" do
    sync @colors, name: "Weird Name!!"

    assert_response :no_content
    assert_equal "weird-name-", @user.reload.synced_theme["slug"]
  end

  test "colors that aren't a theme" do
    sync "nothing to see here"

    assert_response :unprocessable_content
    assert_nil @user.reload.theme
  end

  test "a wrong key" do
    sync @colors, token: "wrong"

    assert_response :unauthorized
    assert_nil @user.reload.theme
  end

  test "no key" do
    put theme_sync_url, params: @colors, headers: { "Content-Type" => "text/plain" }

    assert_response :unauthorized
  end

  test "a reset key stops working" do
    old_token = @user.theme_sync_token
    @user.reset_theme_sync_token

    sync @colors, token: old_token
    assert_response :unauthorized
  end

  test "a deactivated person's key stops working" do
    @user.deactivate

    sync @colors
    assert_response :unauthorized
  end

  test "any content type, even one Rails parses as params first" do
    put theme_sync_url, params: @colors, headers: {
      "Authorization" => "Bearer #{@user.theme_sync_token}", "X-Theme-Name" => "nord",
      "Content-Type" => "application/x-www-form-urlencoded"
    }

    assert_response :no_content
    assert_equal "nord", @user.reload.synced_theme["slug"]
  end

  test "markup in colors and names never reaches the page" do
    sync <<~TOML, name: "</style><img src=x onerror=alert(1)>"
      mode = "dark;}body{display:none"
      background = "#000000"
      foreground = "#ffffff"
      accent = "#ff0000"
      red = "#000000</style><script>alert(1)</script>"
    TOML
    assert_response :no_content

    sign_in :david
    get edit_account_url
    assert_no_match(/<script>alert|onerror=|display:none/, response.body)
    assert_select "style#theme_style[data-mode=dark]"
  end

  test "too much" do
    sync "a" * (Users::ThemeSyncsController::MAX_BODY_BYTES + 1)

    assert_response :content_too_large
  end

  private
    def sync(colors, name: "tokyo-night", token: @user.theme_sync_token)
      put theme_sync_url, params: colors, headers: {
        "Authorization" => "Bearer #{token}", "X-Theme-Name" => name, "Content-Type" => "text/plain",
        "User-Agent" => "curl/8.10.1"
      }
    end
end
