class UserWebauthnIdentity < ApplicationRecord
  belongs_to :user

  has_one :user_webauthn_credential,
    foreign_key: :webauthn_user_id,
    primary_key: :webauthn_user_id,
    inverse_of: :user_webauthn_identity

  validates :user_id, uniqueness: true
  validates :webauthn_user_id, presence: true, uniqueness: true

  before_validation :set_webauthn_user_id, on: :create

  private

  def set_webauthn_user_id
    self.webauthn_user_id ||= WebAuthn.generate_user_id
  end
end
