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

  # Returns the challenge only to the single caller that actually deletes the key.
  # Rails.cache.delete returns true only when the key existed, so concurrent callers
  # that read the same challenge cannot all pass this gate.
  def consume(purpose, request_id)
    return if request_id.blank?

    key = cache_key(purpose, request_id)
    challenge = Rails.cache.read(key)
    return unless challenge && Rails.cache.delete(key)

    challenge
  end

  def cache_key(purpose, request_id)
    "webauthn:#{purpose}:#{request_id}"
  end
  private_class_method :cache_key
end
