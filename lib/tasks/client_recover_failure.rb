require_relative "client_helper"

client = ClientHelper.new_fake_client

puts "\n手順 1・2（登録用 options 取得・公開鍵登録）は実行しません。"
puts "\n── 3. 復元用 options 取得 ──"
puts "POST /api/v1/recovery/options"
recovery = ClientHelper.post_json("/api/v1/recovery/options")
ClientHelper.print_json "Response", recovery

puts "\n── 4. 未登録の公開鍵を使った検証（復元失敗を期待） ──"

recovery_options = recovery.fetch("publicKeyOption")
rp_id = ClientHelper.rp_id_from(recovery_options)

# FakeClient needs a local credential to sign an assertion that reaches the server's lookup.
client.create(rp_id: rp_id)
puts "署名用の鍵はクライアント内でのみ生成し、サーバーには登録しません。"

assertion = client.get(
  challenge: recovery_options.fetch("challenge"),
  rp_id: rp_id,
  allow_credentials: ClientHelper.allow_credential_ids_from(recovery_options)
)

recovery_request = {
  recovery_id: recovery.fetch("recovery_id"),
  credential: assertion
}

ClientHelper.print_json "Request", recovery_request
ClientHelper.print_decoded_assertion(assertion)

puts "\nPOST /api/v1/recovery"

response = ClientHelper.post_json("/api/v1/recovery", recovery_request, expected_status: 404)
ClientHelper.print_json "Response", response
puts "\n検証成功: 手順 1・2 を省いた復元リクエストが HTTP 404 で拒否されました。"
