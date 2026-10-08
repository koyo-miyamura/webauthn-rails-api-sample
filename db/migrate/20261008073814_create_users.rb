class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :integer do |t|
      t.timestamps
    end
  end
end
