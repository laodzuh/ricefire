class AddThemesToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :theme, :string
    add_column :users, :synced_theme, :json
    add_column :users, :theme_sync_token, :string
    add_index :users, :theme_sync_token, unique: true
  end
end
