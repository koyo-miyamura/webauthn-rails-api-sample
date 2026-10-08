class User < ApplicationRecord
  has_one :user_webauthn_identity
end
