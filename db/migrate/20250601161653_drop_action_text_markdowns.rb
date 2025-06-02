class DropActionTextMarkdowns < ActiveRecord::Migration[8.1]
  def change
    drop_table :action_text_markdowns
  end
end
