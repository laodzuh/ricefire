class CreateRadio < ActiveRecord::Migration[8.2]
  def change
    create_table :radio_stations do |t|
      t.string :source, null: false, default: "playlist"
      t.bigint :epoch_ms, null: false
      t.string :stream_url
      t.timestamps
    end

    create_table :radio_tracks do |t|
      t.string :title
      t.string :artist
      t.integer :duration_ms
      t.integer :position, null: false
      t.string :status, null: false, default: "processing"
      t.timestamps
    end

    add_index :radio_tracks, :position
  end
end
