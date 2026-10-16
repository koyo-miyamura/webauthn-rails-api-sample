class Api::V1::RecoveriesController < ApplicationController
  def options
    # 未ログインを前提とする
    get_options = WebAuthn::Credential.options_for_get(
      rp_id: WebAuthn.configuration.rp_id,
      user_verification: "discouraged"
    )
    request_id = WebauthnChallengeRequest.issue(:recovery, get_options.challenge)

    render json: {
      requestId: request_id,
      publicKeyOption: get_options
    }
  end

  def create
    request_id = params[:requestId]
    webauthn_credential = WebAuthn::Credential.from_get(params[:credential])

    user_webauthn_credential = UserWebauthnCredential.find_by(credential_id: webauthn_credential.id)
    unless user_webauthn_credential
      return render json: { error: "Credential not found" }, status: :not_found
    end

    get_options_challenge = WebauthnChallengeRequest.challenge(:recovery, request_id)
    unless get_options_challenge
      return render json: { error: "Recovery request is no longer available" },
        status: :unprocessable_entity
    end

    begin
      webauthn_credential.verify(
        get_options_challenge,
        public_key: user_webauthn_credential.public_key,
        sign_count: user_webauthn_credential.sign_count,
        user_presence: false # ユーザー認証なしで検証するので、UP フラグの検証スキップ
      )

      # 並行リクエスト対策としてキャッシュから削除できなければエラーを返す
      unless WebauthnChallengeRequest.consume(:recovery, request_id)
        return render json: { error: "Recovery request is no longer available" },
          status: :unprocessable_entity
      end

      user_webauthn_credential.update!(sign_count: webauthn_credential.sign_count)

      # 今回は省略するが、実際にはここでログイン処理などを行う

      render json: { success: true }
    rescue WebAuthn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
