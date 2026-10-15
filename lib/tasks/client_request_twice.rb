require_relative "client_helper"

def register(client, step)
  puts "\n── #{step}. 登録用 options 取得 ──"
  puts "POST /api/v1/registration/options"
  options = ClientHelper.post_json("/api/v1/registration/options")
  ClientHelper.print_json "Response", options

  puts "\n── #{step + 1}. 公開鍵登録 ──"
  create_options = options.fetch("publicKeyOption")
  registration = client.create(
    challenge: create_options.fetch("challenge"),
    rp_id: ClientHelper.rp_id_from(create_options)
  )
  registration_request = {
    requestId: options.fetch("requestId"),
    credential: registration
  }

  ClientHelper.print_json "Request", registration_request
  ClientHelper.print_decoded_attestation(registration)

  puts "\nPOST /api/v1/registration"
  response = ClientHelper.post_json("/api/v1/registration", registration_request)
  ClientHelper.print_json "Response", response
end

def recover(client, step)
  puts "\n── #{step}. 復元用 options 取得 ──"
  puts "POST /api/v1/recovery/options"
  recovery = ClientHelper.post_json("/api/v1/recovery/options")
  ClientHelper.print_json "Response", recovery

  puts "\n── #{step + 1}. 公開鍵を使った検証（復元） ──"
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
end

first_client = ClientHelper.new_fake_client
second_client = ClientHelper.new_fake_client

puts "\n━━ 1 回目: 1 つ目の鍵で登録 → 復元 ━━"
register(first_client, 1)
recover(first_client, 3)

puts "\n━━ 2 回目: 2 つ目の鍵で登録 → 復元 ━━"
puts "登録用 options の excludeCredentials に 1 つ目の鍵が含まれます。"
register(second_client, 5)
recover(second_client, 7)

puts "\n━━ 追加確認: 2 つ目の鍵を登録した後も 1 つ目の鍵で復元できる ━━"
recover(first_client, 9)

puts "\n検証成功: 2 つの鍵を登録し、どちらの鍵でも復元できました。"
