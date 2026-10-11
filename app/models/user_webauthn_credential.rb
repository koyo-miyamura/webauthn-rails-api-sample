class UserWebauthnCredential < ApplicationRecord
  belongs_to :user_webauthn_identity,
    foreign_key: :webauthn_user_id,
    primary_key: :webauthn_user_id,
    inverse_of: :user_webauthn_credential

  validates :webauthn_user_id, uniqueness: true
  validates :credential_id, presence: true, uniqueness: true
  validates :public_key, presence: true
end
