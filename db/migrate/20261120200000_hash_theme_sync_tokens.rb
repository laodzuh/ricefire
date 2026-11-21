# Keeps only a SHA-256 digest of each theme sync key, so a copy of the database can't be used to send themes.
# Existing keys are digested in place, so hooks that are already set up keep working. The digest has to match
# User::Theming.theme_sync_digest, but is written out here so later changes to the model can't change this migration.
class HashThemeSyncTokens < ActiveRecord::Migration[8.2]
  def up
    add_column :users, :theme_sync_token_digest, :string
    add_index :users, :theme_sync_token_digest, unique: true

    select_rows("SELECT id, theme_sync_token FROM users WHERE theme_sync_token IS NOT NULL").each do |id, token|
      execute "UPDATE users SET theme_sync_token_digest = #{quote(Digest::SHA256.hexdigest(token))} WHERE id = #{Integer(id)}"
    end

    remove_index :users, :theme_sync_token
    remove_column :users, :theme_sync_token
  end

  def down
    # A digest can't be turned back into the key it came from
    raise ActiveRecord::IrreversibleMigration
  end
end
