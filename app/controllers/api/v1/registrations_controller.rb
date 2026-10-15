class Api::V1::RegistrationsController < ApplicationController
  def options
    user_identity = UserWebauthnIdentity.find_or_create_by!(user: current_user)

    create_options = WebAuthn::Credential.options_for_create(
      user: {
        id: user_identity.webauthn_user_id,
        name: "usercode-#{user_identity.webauthn_user_id}"
      },
      authenticator_selection: {
        resident_key: "required"
      },
      exclude: user_identity.user_webauthn_credentials.pluck(:credential_id)
    )

    # チャレンジの保存。Redis や Cookie などでも良い。
    Rails.cache.write(cache_key(user_identity), create_options.challenge, expires_in: 30.minutes)

    render json: { publicKeyOption: create_options }
  end

  def create
    user_identity = current_user.user_webauthn_identity
    cached_challenge = user_identity && Rails.cache.read(cache_key(user_identity))
    unless cached_challenge
      return render json: { error: "Registration request is no longer available" },
        status: :unprocessable_entity
    end

    webauthn_credential = WebAuthn::Credential.from_create(params)

    begin
      webauthn_credential.verify(cached_challenge)

      # 並行リクエスト対策としてキャッシュから削除できなければエラーを返す
      unless Rails.cache.delete(cache_key(user_identity))
        return render json: { error: "Registration request is no longer available" },
          status: :unprocessable_entity
      end

      user_identity.user_webauthn_credentials.create!(
        credential_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count
      )

      render json: { status: "ok" }, status: :ok
    rescue WebAuthn::SignCountVerificationError => e
      # sign_count の検証に失敗した時エラーにするかはアプリケーションの方針次第（同期パスキーなどのケースではエラーにしないこともある）
      # エラーにしない場合は以下
      # render json: { status: "ok" }, status: :ok
      render json: { error: e.message }, status: :unprocessable_entity
    rescue WebAuthn::Error, ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def cache_key(user_identity)
    "webauthn:registration:#{user_identity.webauthn_user_id}"
  end
end
