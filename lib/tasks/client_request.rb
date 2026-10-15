require_relative "client_helper"

client = ClientHelper.new_fake_client

puts "\n── 1. 登録用 options 取得 ──"
puts "POST /api/v1/registration/options"
options = ClientHelper.post_json("/api/v1/registration/options")
ClientHelper.print_json "Response", options

puts "\n── 2. 公開鍵登録 ──"

create_options = options.fetch("publicKeyOption")
registration = client.create(
  challenge: create_options.fetch("challenge"),
  rp_id: ClientHelper.rp_id_from(create_options)
)

ClientHelper.print_json "Request", registration
ClientHelper.print_decoded_attestation(registration)

puts "\nPOST /api/v1/registration"
response = ClientHelper.post_json("/api/v1/registration", registration)
ClientHelper.print_json "Response", response

puts "\n── 3. 復元用 options 取得 ──"
puts "POST /api/v1/recovery/options"
recovery = ClientHelper.post_json("/api/v1/recovery/options")
ClientHelper.print_json "Response", recovery

puts "\n── 4. 公開鍵を使った検証（復元） ──"

recovery_options = recovery.fetch("publicKeyOption")
assertion = client.get(
  challenge: recovery_options.fetch("challenge"),
  rp_id: ClientHelper.rp_id_from(recovery_options),
  allow_credentials: ClientHelper.allow_credential_ids_from(recovery_options)
)

recovery_request = {
  requestId: recovery.fetch("requestId"),
  credential: assertion
}

ClientHelper.print_json "Request", recovery_request
ClientHelper.print_decoded_assertion(assertion)

puts "\nPOST /api/v1/recovery"
response = ClientHelper.post_json("/api/v1/recovery", recovery_request)
ClientHelper.print_json "Response", response
