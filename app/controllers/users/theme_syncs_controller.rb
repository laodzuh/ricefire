# Where Omarchy's theme-set hook sends the theme it just switched to: the theme's name in X-Theme-Name and its
# colors.toml as the body, authenticated by the person's theme sync key rather than a session, so there's no cookie
# and nothing to forge.
class Users::ThemeSyncsController < ApplicationController
  MAX_BODY_BYTES = 16.kilobytes

  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

  before_action :authenticate_by_theme_sync_token

  def update
    colors = read_colors

    if colors.bytesize > MAX_BODY_BYTES
      head :content_too_large
    elsif @user.sync_theme(request.headers["X-Theme-Name"], colors)
      head :no_content
    else
      head :unprocessable_content
    end
  end

  private
    # From the start, whatever the content type: a form or JSON body may already have been read to parse params.
    def read_colors
      request.body.rewind
      String.new(request.body.read(MAX_BODY_BYTES + 1).to_s, encoding: Encoding::UTF_8).scrub
    end

    def authenticate_by_theme_sync_token
      token = request.authorization.to_s[/\ABearer (.+)\z/, 1]&.strip
      @user = User.find_by_theme_sync_token(token) or head :unauthorized
    end
end
