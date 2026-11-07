class Users::ThemeSyncTokensController < ApplicationController
  def create
    Current.user.reset_theme_sync_token

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("omarchy", partial: "users/themes/sync", locals: { user: Current.user, open: true })
      end
      format.html { redirect_to edit_account_url(anchor: "omarchy") }
    end
  end
end
