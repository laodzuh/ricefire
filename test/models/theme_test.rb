require "test_helper"

class ThemeTest < ActiveSupport::TestCase
  test "every bundled Omarchy theme is valid" do
    assert Theme.bundled.size >= 20
    Theme.bundled.each_value { |theme| assert theme.valid?, "#{theme.slug} isn't valid" }
  end

  test "names and modes" do
    assert_equal "Tokyo Night", Theme.find("tokyo-night").name
    assert_equal "dark", Theme.find("tokyo-night").mode
    assert_equal "light", Theme.find("catppuccin-latte").mode
  end

  test "renders Campfire's named colors" do
    css = Theme.find("tokyo-night").to_css

    assert_match "color-scheme:dark;", css
    assert_match(/--lch-white:\d+\.\d\d% \d\.\d{4} \d+\.\d\d;/, css)
    assert_match(/--keyword:oklch\(/, css)
  end

  test "keeps only hex colors, so nothing else reaches the page" do
    theme = Theme.from_toml("evil", <<~TOML)
      background = "#000000;}body{display:none"
      foreground = "#ffffff"
      accent = "url(https://example.com)"
      red = "#FF0000"
    TOML

    assert_equal({ "foreground" => "#ffffff", "red" => "#ff0000" }, theme.colors)
    assert_not theme.valid?
  end

  test "ignores comments and unknown keys" do
    theme = Theme.from_toml("plain", <<~TOML)
      # a comment
      mode = "light"
      background = "#ffffff" # trailing
      foreground = "#000000"
      accent = "#3366ff"
      hyprland_active_border = "#123456"
    TOML

    assert theme.valid?
    assert_equal "light", theme.mode
    assert_not theme.colors.key?("hyprland_active_border")
  end

  test "infers the mode when it's missing" do
    assert_equal "light", Theme.from_toml("x", %(background = "#fafafa"\nforeground = "#111111"\naccent = "#0000ff")).mode
    assert_equal "dark", Theme.from_toml("x", %(background = "#111111"\nforeground = "#fafafa"\naccent = "#0000ff")).mode
  end

  test "rejects slugs that aren't Omarchy-style names" do
    assert_not Theme.from_toml("Bad Name!", Theme::DIRECTORY.join("nord.toml").read).valid?
  end

  test "oklab conversion" do
    assert_equal "100.00% 0.0000 0.00", Theme::Oklab.from_hex("#ffffff").to_lch
    assert_equal "0.00% 0.0000 0.00", Theme::Oklab.from_hex("#000000").to_lch
    assert_equal "62.80% 0.2577 29.23", Theme::Oklab.from_hex("#ff0000").to_lch
  end
end
