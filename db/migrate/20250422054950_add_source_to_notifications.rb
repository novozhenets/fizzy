class AddSourceToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_reference :notifications, :source, polymorphic: true, index: true

    execute <<~SQL
      update notifications set source_type = 'Event', source_id = event_id;
    SQL

    change_column_null :notifications, :source_type, false
  end
end
