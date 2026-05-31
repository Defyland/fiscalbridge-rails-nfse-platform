class HardenWebSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :expires_at, :datetime
    add_column :sessions, :last_seen_at, :datetime

    execute <<~SQL.squish
      UPDATE sessions
         SET expires_at = created_at + interval '12 hours',
             last_seen_at = COALESCE(updated_at, created_at)
       WHERE expires_at IS NULL
    SQL

    change_column_null :sessions, :expires_at, false
    add_index :sessions, :expires_at
    add_index :sessions, [ :user_id, :expires_at ]
  end

  def down
    remove_index :sessions, [ :user_id, :expires_at ]
    remove_index :sessions, :expires_at
    remove_column :sessions, :last_seen_at
    remove_column :sessions, :expires_at
  end
end
