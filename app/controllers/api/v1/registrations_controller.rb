class Api::V1::RegistrationsController < ApplicationController
  def options
    user_identity = UserWebauthnIdentity.find_or_create_by!(user: current_user)

    create_options = WebAuthn::Credential.options_for_create(
      user: {
        id: user_identity.webauthn_user_id,
        name: "usercode-#{user_identity.webauthn_user_id}"
      },
      authenticator_selection: {
        resident_key: "required",
        user_verification: "discouraged"
      },
      exclude: user_identity.user_webauthn_credentials.map(&:credential_id_base64)
    )

    request_id = WebauthnChallengeRequest.issue(:registration, create_options.challenge)

    render json: {
      requestId: request_id,
      publicKeyOption: create_options
    }
  end

  def create
    request_id = params[:requestId]
    user_identity = current_user.user_webauthn_identity
    # チャレンジは検証結果にかかわらず使い切る。並行リクエストで消費できるのは 1 つだけ
    cached_challenge = user_identity && WebauthnChallengeRequest.consume(:registration, request_id)
    unless cached_challenge
      return render json: { error: "Registration request is no longer available" },
        status: :unprocessable_entity
    end

    webauthn_credential = WebAuthn::Credential.from_create(params[:credential])

    begin
      webauthn_credential.verify(cached_challenge)

      user_identity.user_webauthn_credentials.create!(
        credential_id: webauthn_credential.raw_id, # NOTE: 保存するのは Base64URL 文字列の id ではなくデコード済みバイト列の raw_id
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
end
