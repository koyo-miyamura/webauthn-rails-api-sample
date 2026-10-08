class ApplicationController < ActionController::API
  def current_user
    # NOTE: 通常は認証済みのユーザーを用いるなどをするが、サンプルのため seed で作成された対象のユーザーで固定する。
    @current_user ||= User.first
  end
end
