require "net/http"
require "json"
require "webauthn/fake_client"

def post_json(path, body = {})
  uri = URI("http://localhost:3000#{path}")
  res = Net::HTTP.post(
    uri,
    JSON.generate(body),
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  )

  raise "HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

  JSON.parse(res.body)
end

origin = WebAuthn.configuration.allowed_origins.fetch(0)
client = WebAuthn::FakeClient.new(origin)

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
puts "\nPOST /api/v1/registration"

response = post_json("/api/v1/registration", registration)

puts "\nResponse:"
puts JSON.pretty_generate(response)
