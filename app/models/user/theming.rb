# A person's color theme: one of the bundled Omarchy themes, picked on their profile, or the colors their own
# Omarchy sends whenever they switch themes there. A sync also selects the synced theme, so switching in Omarchy
# always wins; picking a bundled theme afterwards sticks until the next switch.
module User::Theming
  extend ActiveSupport::Concern

  SYNCED = "omarchy"

  included do
    validates :theme, inclusion: { in: ->(_) { Theme.bundled.keys + [ SYNCED ] } }, allow_nil: true
    after_update_commit :broadcast_theme, if: -> { saved_change_to_theme? || saved_change_to_synced_theme? }
  end

  class_methods do
    def find_by_theme_sync_token(token)
      active.without_bots.find_by(theme_sync_token: token) if token.present?
    end
  end

  def current_theme
    if theme == SYNCED
      synced
    else
      Theme.find(theme)
    end
  end

  def synced
    Theme.from_h(synced_theme) if synced_theme.present?
  end

  def sync_theme(slug, toml)
    slug = slug.to_s.downcase.gsub(/[^a-z0-9-]/, "-").squeeze("-").delete_prefix("-").first(40).presence || SYNCED
    theme = Theme.from_toml(slug, toml)
    theme.valid? && update(theme: SYNCED, synced_theme: theme.to_h)
  end

  def reset_theme_sync_token
    update! theme_sync_token: SecureRandom.base58(32)
  end

  private
    # Pages this person has open switch without a reload
    def broadcast_theme
      broadcast_replace_to self, :theme, target: "theme_style", partial: "users/themes/style", locals: { theme: current_theme }
    rescue => error
      Rails.logger.warn "Could not broadcast a theme change: #{error.class}"
    end
end
