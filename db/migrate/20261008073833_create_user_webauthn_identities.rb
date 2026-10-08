class CreateUserWebauthnIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :user_webauthn_identities, id: :integer do |t|
      t.references :user, index: {unique: true}, null: false, foreign_key: true, type: :integer
      t.string :webauthn_user_id, null: false

      t.timestamps
    end
    add_index :user_webauthn_identities, :webauthn_user_id, unique: true
  end
end
