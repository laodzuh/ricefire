# sRGB hex colors converted to OKLab, where mixing looks even, and written out as the OKLCH triplets colors.css
# uses. Conversion matrices from https://bottosson.github.io/posts/oklab/
class Theme::Oklab
  attr_reader :lightness, :a, :b

  def self.from_hex(hex)
    red, green, blue = hex.delete_prefix("#").scan(/../).map { |channel| linearize(channel.to_i(16) / 255.0) }

    l = Math.cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
    m = Math.cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
    s = Math.cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)

    new \
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  end

  def self.linearize(channel)
    channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
  end

  def initialize(lightness, a, b)
    @lightness, @a, @b = lightness, a, b
  end

  # The share of other in the mix, from 0 (all self) to 1 (all other)
  def mix(other, amount)
    self.class.new \
      lightness + (other.lightness - lightness) * amount,
      a + (other.a - a) * amount,
      b + (other.b - b) * amount
  end

  def chroma
    Math.hypot(a, b)
  end

  def hue
    chroma < 0.0001 ? 0 : Math.atan2(b, a) * 180 / Math::PI % 360
  end

  # As colors.css writes named colors, for use inside oklch()
  def to_lch
    format("%.2f%% %.4f %.2f", lightness.clamp(0, 1) * 100, chroma, hue)
  end

  def to_css
    "oklch(#{to_lch})"
  end

  # The filter that turns black into the gray with this color's lightness: invert(n) maps black to the sRGB gray n
  def to_invert_filter
    linear = lightness.clamp(0, 1)**3
    gray = linear <= 0.0031308 ? linear * 12.92 : 1.055 * linear**(1 / 2.4) - 0.055

    format("invert(%.1f%%)", gray * 100)
  end
end
