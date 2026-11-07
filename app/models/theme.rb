# A color theme in Omarchy's colors.toml format, rendered as overrides of the named colors in colors.css.
#
# The bundled themes are Omarchy's own, copied into config/themes. A user's Omarchy can also send its current
# colors.toml (Users::ThemeSyncsController), which is why parsing keeps only what a theme uses and accepts only hex
# colors: the CSS this renders goes straight into the page.
class Theme
  DIRECTORY = Rails.root.join("config/themes")

  KEYS = %w[ background dark_background darker_background lighter_background foreground dark_foreground
    accent selection muted red green orange yellow blue cyan magenta ].freeze
  REQUIRED_KEYS = %w[ background foreground accent ].freeze
  MODES = %w[ dark light ].freeze

  HEX_COLOR = /\A#\h{6}\z/
  SLUG = /\A[a-z0-9][a-z0-9-]{0,39}\z/

  attr_reader :slug, :mode, :colors

  class << self
    def bundled
      @bundled ||= DIRECTORY.glob("*.toml").sort.to_h do |path|
        slug = path.basename(".toml").to_s
        [ slug, from_toml(slug, path.read) ]
      end.freeze
    end

    def find(slug)
      bundled[slug]
    end

    def from_toml(slug, toml)
      values = parse(toml)
      new(slug: slug, mode: values["mode"], colors: values)
    end

    def from_h(hash)
      new(slug: hash["slug"], mode: hash["mode"], colors: hash["colors"] || {})
    end

    # colors.toml is flat `key = "value"` lines, so that's all this reads.
    def parse(toml)
      toml.to_s.each_line.filter_map do |line|
        if match = line.match(/\A\s*([a-z_]+)\s*=\s*"([^"]*)"\s*(#.*)?\s*\z/)
          [ match[1], match[2].strip.downcase ]
        end
      end.to_h
    end
  end

  def initialize(slug:, mode:, colors:)
    @slug = slug.to_s
    @colors = colors.to_h.slice(*KEYS).select { |_, value| value.to_s.match?(HEX_COLOR) }
    @mode = MODES.include?(mode) ? mode : inferred_mode
  end

  def name
    slug.titleize
  end

  def valid?
    slug.match?(SLUG) && REQUIRED_KEYS.all? { |key| colors.key?(key) }
  end

  def dark?
    mode == "dark"
  end

  def to_h
    { "slug" => slug, "mode" => mode, "colors" => colors }
  end

  # A few colors for showing the theme in a picker
  def swatches
    colors.values_at("background", "foreground", "accent", "red", "green", "yellow").compact
  end

  def to_css
    variables = named_colors.transform_values(&:to_lch)
      .merge(code_colors.transform_values(&:to_css))
      .merge(palette_variables)

    ":root{color-scheme:#{mode};" + variables.map { |name, value| "--#{name}:#{value};" }.join + "}"
  end

  private
    def color(key)
      Oklab.from_hex(colors[key]) if colors[key]
    end

    def background = color("background")
    def foreground = color("foreground")
    def accent = color("accent")

    # Campfire's color names describe light mode: "white" is the page and "black" is the text, whatever the theme.
    # Omarchy's background variants run the other way in light themes (lighter_background is the darker one), so
    # the surfaces come from different keys depending on the mode.
    def named_colors
      surface, border = dark? ? %w[ lighter_background selection ] : %w[ dark_background darker_background ]

      {
        "lch-white" => background,
        "lch-black" => foreground,
        "lch-gray" => color(surface) || background.mix(foreground, 0.06),
        "lch-gray-dark" => color(border) || background.mix(foreground, 0.12),
        "lch-gray-darker" => color("muted") || background.mix(foreground, 0.35),
        "lch-blue" => accent,
        "lch-blue-light" => background.mix(accent, 0.2),
        "lch-blue-dark" => background.mix(accent, 0.45),
        "lch-orange" => color("orange") || color("yellow") || accent,
        "lch-red" => color("red") || accent,
        "lch-green" => color("green") || accent
      }
    end

    # The syntax highlighting palette in code.css
    def code_colors
      {
        "keyword" => color("magenta") || accent,
        "entity" => color("blue") || accent,
        "constant" => color("cyan") || accent,
        "string" => color("green") || accent,
        "variable" => color("yellow") || accent,
        "comment" => foreground.mix(background, 0.45),
        "entity-tag" => color("green") || accent,
        "markup-heading" => color("blue") || accent,
        "markup-list" => color("yellow") || accent,
        "markup-inserted" => color("green") || accent,
        "markup-deleted" => color("red") || accent
      }
    end

    # For themes.css, which spreads the theme further than colors.css reaches: a panel color for the sidebar, and
    # filters that turn Campfire's black icons into the theme's text color, or its background color on accent buttons.
    # A filter can only set an icon's brightness, so icons match the color's lightness rather than its hue.
    def palette_variables
      {
        "theme-panel" => (color("dark_background") || background.mix(foreground, 0.04)).to_lch,
        "theme-icon-filter" => foreground.to_invert_filter,
        "theme-icon-on-accent-filter" => background.to_invert_filter
      }
    end

    def inferred_mode
      colors["background"] && Oklab.from_hex(colors["background"]).lightness > 0.6 ? "light" : "dark"
    end
end
