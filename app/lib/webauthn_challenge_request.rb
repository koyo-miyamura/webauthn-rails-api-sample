# Issues a one-time requestId bound to a WebAuthn challenge so that the same user can
# run several registration or recovery ceremonies concurrently without clobbering each other.
module WebauthnChallengeRequest
  module_function

  EXPIRES_IN = 30.minutes

  def issue(purpose, challenge)
    request_id = SecureRandom.hex(32)
    Rails.cache.write(cache_key(purpose, request_id), challenge, expires_in: EXPIRES_IN)
    request_id
  end

  def challenge(purpose, request_id)
    return if request_id.blank?

    Rails.cache.read(cache_key(purpose, request_id))
  end

  def consume(purpose, request_id)
    Rails.cache.delete(cache_key(purpose, request_id))
  end

  def cache_key(purpose, request_id)
    "webauthn:#{purpose}:#{request_id}"
  end
  private_class_method :cache_key
end
