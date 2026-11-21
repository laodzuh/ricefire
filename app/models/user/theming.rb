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
      active.without_bots.find_by(theme_sync_token_digest: theme_sync_digest(token)) if token.present?
    end

    # The key is long and random, so a fast hash is enough: there's nothing to guess
    def theme_sync_digest(token)
      Digest::SHA256.hexdigest(token)
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

  # Returns the new key. Only its digest is stored, so this is the one chance to show it.
  def reset_theme_sync_token
    SecureRandom.base58(32).tap do |token|
      update! theme_sync_token_digest: self.class.theme_sync_digest(token)
    end
  end

  def syncing_theme?
    theme_sync_token_digest.present?
  end

  private
    # Pages this person has open switch without a reload
    def broadcast_theme
      broadcast_replace_to self, :theme, target: "theme_style", partial: "users/themes/style", locals: { theme: current_theme }
    rescue => error
      Rails.logger.warn "Could not broadcast a theme change: #{error.class}"
    end
end
