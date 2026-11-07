class Users::ThemeSyncTokensController < ApplicationController
  def create
    Current.user.reset_theme_sync_token
    redirect_to user_theme_url(anchor: "omarchy"), notice: "✓"
  end
end
