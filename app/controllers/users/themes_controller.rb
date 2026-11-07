class Users::ThemesController < ApplicationController
  before_action :set_user

  def show
  end

  def update
    if @user.update(theme: params.dig(:user, :theme).presence)
      redirect_to user_theme_url, notice: "✓"
    else
      redirect_to user_theme_url, alert: "That theme isn't available."
    end
  end

  private
    def set_user
      @user = Current.user
    end
end
