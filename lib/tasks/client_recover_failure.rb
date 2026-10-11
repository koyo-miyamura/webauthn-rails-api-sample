require "net/http"
require "json"
require "webauthn/fake_client"

BASE_URL = ENV.fetch("API_BASE_URL", "http://localhost:3000")
ENCODER = WebAuthn::Encoder.new(WebAuthn.configuration.encoding)

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

def decode_client_data_json(encoded)
  JSON.parse(ENCODER.decode(encoded))
end

def decode_authenticator_data(raw)
  auth_data = WebAuthn::AuthenticatorData.deserialize(raw)

  {
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
end

def print_decoded(label, value)
  puts "\nDecoded #{label}:"
  puts JSON.pretty_generate(value)
end

origin = WebAuthn.configuration.allowed_origins.fetch(0)
client = WebAuthn::FakeClient.new(origin)

puts "\n手順 1・2（登録用 options 取得・公開鍵登録）は実行しません。"
puts "\n── 3. 復元用 options 取得 ──"
puts "POST /api/v1/recovery/options"
recovery = post_json("/api/v1/recovery/options")
puts "\nResponse:"
puts JSON.pretty_generate(recovery)

puts "\n── 4. 未登録の公開鍵を使った検証（復元失敗を期待） ──"

recovery_options = recovery.fetch("options")
rp_id = recovery_options["rpId"] || URI(origin).host

# FakeClient needs a local credential to sign an assertion that reaches the server's lookup.
client.create(rp_id: rp_id)
puts "署名用の鍵はクライアント内でのみ生成し、サーバーには登録しません。"

assertion = client.get(
  challenge: recovery_options.fetch("challenge"),
  rp_id: rp_id,
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

# An unregistered credential raises ActiveRecord::RecordNotFound in RecoveriesController.
response = post_json("/api/v1/recovery", recovery_request, expected_status: 404)

puts "\nResponse:"
puts JSON.pretty_generate(response)
puts "\n検証成功: 手順 1・2 を省いた復元リクエストが HTTP 404 で拒否されました。"
