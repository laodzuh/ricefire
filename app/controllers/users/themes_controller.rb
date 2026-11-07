# The theme picker on the profile. Answers in place, swapping in the new theme's styles, so the page doesn't reload
# and its back button still goes where it did.
class Users::ThemesController < ApplicationController
  def update
    if Current.user.update(theme: params.dig(:user, :theme).presence)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("theme_style", partial: "users/themes/style", locals: { theme: Current.user.current_theme })
        end
        format.html { redirect_to user_profile_url(anchor: "theme") }
      end
    else
      redirect_to user_profile_url(anchor: "theme"), alert: "That theme isn't available."
    end
  end
end
