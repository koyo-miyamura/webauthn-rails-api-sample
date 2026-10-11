class Api::V1::RecoveriesController < ApplicationController
  def options
    # 未ログインを前提とする
    get_options = WebAuthn::Credential.options_for_get
    recovery_id = SecureRandom.hex(32)

    Rails.cache.write(cache_key(recovery_id), get_options.challenge, expires_in: 30.minutes)

    render json: {
      recovery_id: recovery_id,
      options: get_options
    }
  end

  def create
    recovery_id = params[:recovery_id]
    webauthn_credential = WebAuthn::Credential.from_get(params[:credential])

    user_webauthn_credential = UserWebauthnCredential.find_by(credential_id: webauthn_credential.id)
    unless user_webauthn_credential
      return render json: { error: "Credential not found" }, status: :not_found
    end

    get_options_challenge = Rails.cache.read(cache_key(recovery_id))

    begin
      webauthn_credential.verify(
        get_options_challenge,
        public_key: user_webauthn_credential.public_key,
        sign_count: 0 # sign_count は任意なので今回は検証しない
      )

      # 並行リクエスト対策としてキャッシュから削除できなければエラーを返す
      unless Rails.cache.delete(cache_key(recovery_id))
        return render json: { error: "Recovery request is no longer available" },
          status: :unprocessable_entity
      end

      # 今回は省略するが、実際にはここでログイン処理などを行う

      render json: { success: true }
    rescue WebAuthn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def cache_key(recovery_id)
    "webauthn:recovery:#{recovery_id}"
  end
end
