require "net/http"
require "json"
require "webauthn/fake_client"

module ClientHelper
  BASE_URL = ENV.fetch("API_BASE_URL", "http://localhost:3000")
  ORIGIN = WebAuthn.configuration.allowed_origins.fetch(0)
  ENCODER = WebAuthn::Encoder.new(WebAuthn.configuration.encoding)

  module_function

  def post_json(path, body = {}, expected_status: 200)
    uri = URI("#{BASE_URL}#{path}")
    res = Net::HTTP.post(
      uri,
      JSON.generate(body),
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    )

    puts "\nHTTP #{res.code}"

    unless res.code.to_i == expected_status
      raise "検証失敗: HTTP #{expected_status} を期待しましたが、HTTP #{res.code} が返されました: #{res.body}"
    end

    JSON.parse(res.body)
  end

  def new_fake_client
    WebAuthn::FakeClient.new(ORIGIN)
  end

  def rp_id_from(options)
    options["rpId"] || options.dig("rp", "id") || URI(ORIGIN).host
  end

  def allow_credential_ids_from(options)
    options.fetch("allowCredentials", []).map { |c| c.fetch("id") }.presence
  end

  def decode_client_data_json(encoded)
    JSON.parse(ENCODER.decode(encoded))
  end

  def decode_authenticator_data(raw)
    auth_data = WebAuthn::AuthenticatorData.deserialize(raw)
    flags = auth_data.flags

    decoded = {
      rpIdHash: ENCODER.encode(auth_data.rp_id_hash.to_s),
      flags: {
        userPresent: auth_data.user_present?,
        reservedForFutureUse1: flags.reserved_for_future_use_1.to_i,
        userVerified: auth_data.user_verified?,
        backupEligibility: auth_data.credential_backup_eligible?,
        backupState: auth_data.credential_backed_up?,
        reservedForFutureUse2: flags.reserved_for_future_use_2.to_i,
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
        algorithm: credential.algorithm,
        credentialPublicKey: decode_cose_key(credential.public_key)
      }
    end

    if auth_data.extension_data_included?
      decoded[:extensions] = auth_data.extension_data
    end

    decoded
  end

  # COSE key maps use integer labels; expand them to the names from RFC 9052 / RFC 9053.
  COSE_KEY_LABELS = {
    1 => :kty,
    2 => :kid,
    3 => :alg,
    4 => :key_ops,
    5 => :base_iv,
    -1 => :crv,
    -2 => :x,
    -3 => :y,
    -4 => :d
  }.freeze

  def decode_cose_key(cose_bytes)
    COSE::Key.cbor_decode(cose_bytes).to_h do |label, value|
      name = COSE_KEY_LABELS.fetch(label, label)
      [name, value.is_a?(String) ? ENCODER.encode(value) : value]
    end
  end

  def print_json(label, value)
    puts "\n#{label}:"
    puts JSON.pretty_generate(value)
  end

  def print_decoded_attestation(registration)
    response = registration.fetch("response")
    print_json "Decoded clientDataJSON", decode_client_data_json(response.fetch("clientDataJSON"))

    attestation_object = CBOR.decode(ENCODER.decode(response.fetch("attestationObject")))
    print_json "Decoded authenticatorData (attestationObject.authData)",
      decode_authenticator_data(attestation_object.fetch("authData"))
  end

  def print_decoded_assertion(assertion)
    response = assertion.fetch("response")
    print_json "Decoded clientDataJSON", decode_client_data_json(response.fetch("clientDataJSON"))
    print_json "Decoded authenticatorData", decode_authenticator_data(ENCODER.decode(response.fetch("authenticatorData")))
  end
end
