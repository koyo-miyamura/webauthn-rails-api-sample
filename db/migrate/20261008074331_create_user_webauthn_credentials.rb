class CreateUserWebauthnCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :user_webauthn_credentials do |t|
      t.string :webauthn_user_id, null: false
      t.string :credential_id, null: false
      t.string :public_key, null: false

      t.timestamps
    end
    add_foreign_key :user_webauthn_credentials, :user_webauthn_identities,
      column: :webauthn_user_id, primary_key: :webauthn_user_id
    add_index :user_webauthn_credentials, :webauthn_user_id
    add_index :user_webauthn_credentials, :credential_id, unique: true
    add_index :user_webauthn_credentials, :public_key, unique: true
  end
end
