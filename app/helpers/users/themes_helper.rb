module Users::ThemesHelper
  def theme_sync_hook
    @theme_sync_hook ||= Rails.root.join("contrib/omarchy/theme-set-hook").read
  end
end
