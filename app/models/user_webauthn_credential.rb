class UserWebauthnCredential < ApplicationRecord
  belongs_to :user_webauthn_identity,
    foreign_key: :webauthn_user_id,
    primary_key: :webauthn_user_id,
    inverse_of: :user_webauthn_credentials

  validates :credential_id, presence: true, uniqueness: true
  validates :public_key, presence: true, uniqueness: true

  # credential_id is stored as raw bytes; use this for console logs and API responses
  def credential_id_base64
    WebAuthn.standard_encoder.encode(credential_id)
  end
end
