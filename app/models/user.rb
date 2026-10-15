class User < ApplicationRecord
  has_one :user_webauthn_identity
  has_many :user_webauthn_credentials, through: :user_webauthn_identity
end
