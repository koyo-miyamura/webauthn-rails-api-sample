require "net/http"
require "json"
require "webauthn/fake_client"

BASE_URL = ENV.fetch("API_BASE_URL", "http://localhost:3000")
ENCODER = WebAuthn::Encoder.new(WebAuthn.configuration.encoding)

def post_json(path, body = {})
  uri = URI("#{BASE_URL}#{path}")
  res = Net::HTTP.post(
    uri,
    JSON.generate(body),
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  )

  raise "HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

  JSON.parse(res.body)
end

def decode_client_data_json(encoded)
  JSON.parse(ENCODER.decode(encoded))
end

def decode_authenticator_data(raw)
  auth_data = WebAuthn::AuthenticatorData.deserialize(raw)

  decoded = {
    rpIdHash: ENCODER.encode(auth_data.rp_id_hash.to_s),
    flags: {
      userPresent: auth_data.user_present?,
      userVerified: auth_data.user_verified?,
      backupEligibility: auth_data.credential_backup_eligible?,
      backupState: auth_data.credential_backed_up?,
      attestedCredentialDataIncluded: auth_data.attested_credential_data_included?,
      extensionDataIncluded: auth_data.extension_data_included?
    },
    signCount: auth_data.sign_count.to_i
  }

  if auth_data.attested_credential_data_included?
    credential = auth_data.credential
    decoded[:attestedCredentialData] = {
      aaguid: auth_data.aaguid,
      credentialId: ENCODER.encode(credential.id),
      publicKey: ENCODER.encode(credential.public_key),
      algorithm: credential.algorithm
    }
  end

  decoded
end

def print_decoded(label, value)
  puts "\nDecoded #{label}:"
  puts JSON.pretty_generate(value)
end

origin = WebAuthn.configuration.allowed_origins.fetch(0)
client = WebAuthn::FakeClient.new(origin)

# --------------- 公開鍵登録フェーズ ---------------
puts "\n── 1. options 取得 ──"
puts "POST /api/v1/registration/options"
options = post_json("/api/v1/registration/options")
puts "\nResponse:"
puts JSON.pretty_generate(options)

puts "\n── 2. 公開鍵登録 ──"

registration = client.create(
  challenge: options.fetch("challenge"),
  rp_id: options.dig("rp", "id") || URI(origin).host
)

puts "Request:"
puts JSON.pretty_generate(registration)

print_decoded "clientDataJSON", decode_client_data_json(registration.dig("response", "clientDataJSON"))
attestation_object = CBOR.decode(ENCODER.decode(registration.dig("response", "attestationObject")))
print_decoded "authenticatorData (attestationObject.authData)", decode_authenticator_data(attestation_object.fetch("authData"))

puts "\nPOST /api/v1/registration"

response = post_json("/api/v1/registration", registration)

puts "\nResponse:"
puts JSON.pretty_generate(response)

# --------------- 復元フェーズ ---------------

puts "\n── 3. 復元用 options 取得 ──"
puts "POST /api/v1/recovery/options"
recovery = post_json("/api/v1/recovery/options")
puts "\nResponse:"
puts JSON.pretty_generate(recovery)

puts "\n── 4. 公開鍵を使った検証（復元） ──"

recovery_options = recovery.fetch("options")
assertion = client.get(
  challenge: recovery_options.fetch("challenge"),
  rp_id: recovery_options["rpId"] || URI(origin).host,
  allow_credentials: recovery_options.fetch("allowCredentials", []).map { |c| c.fetch("id") }.presence
)

recovery_request = {
  recovery_id: recovery.fetch("recovery_id"),
  credential: assertion
}

puts "Request:"
puts JSON.pretty_generate(recovery_request)

print_decoded "clientDataJSON", decode_client_data_json(assertion.dig("response", "clientDataJSON"))
print_decoded "authenticatorData", decode_authenticator_data(ENCODER.decode(assertion.dig("response", "authenticatorData")))

puts "\nPOST /api/v1/recovery"

response = post_json("/api/v1/recovery", recovery_request)

puts "\nResponse:"
puts JSON.pretty_generate(response)
