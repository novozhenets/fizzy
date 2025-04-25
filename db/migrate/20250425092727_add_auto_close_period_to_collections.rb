class AddAutoClosePeriodToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :auto_close_period, :bigint

    add_index :collections, :auto_close_period

    execute <<~SQL
      UPDATE collections SET auto_close_period = #{30.days.to_i} WHERE auto_close_period IS NULL;
    SQL
  end
end
