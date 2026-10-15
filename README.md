# WebAuthn Rails API Sample

WebAuthn の鍵をアカウント復元に使うことを想定した Rails API サンプルです。`WebAuthn::FakeClient` で公開鍵登録と署名検証を試せます。

## 起動

Docker と Docker Compose が必要です。ホストに Ruby・Rails をインストールする必要はありません。リポジトリのルートで実行してください。

```bash
docker compose up --build --wait
```

DB と seed は自動で準備され、API は `http://localhost:3000` に起動します。ポートを変える場合は、起動コマンドの先頭に `APP_PORT=3001` などを付けてください。

## 動作確認

### 登録から復元まで

```bash
docker compose exec web bin/rails runner lib/tasks/client_request.rb
```

登録用 options 取得 → 公開鍵登録 → 復元用 options 取得 → 署名検証を実行します。すべて HTTP 200、最後に `{"success":true}` が返れば成功です。再実行すると新しい鍵が追加登録されます。

### 登録から復元までを 2 回実行（複数の鍵）

```bash
docker compose exec web bin/rails runner lib/tasks/client_request_twice.rb
```

別々の鍵で登録 → 復元を 2 回実行し、最後に 1 つ目の鍵で再度復元します。2 回目の登録用 options の `excludeCredentials` に 1 つ目の鍵が含まれ、すべて HTTP 200 なら成功です。1 ユーザーが複数の鍵を保持できることを確認します。

### 署名カウンター（sign_count）の検証

```bash
docker compose exec web bin/rails runner lib/tasks/client_sign_count.rb
```

登録後に復元を 2 回成功させ、次に 1 回目と同じ署名カウンターで復元を試みます。復元 2 回が HTTP 200、カウンターを戻した復元が HTTP 422・`{"error":"WebAuthn::SignCountVerificationError"}` なら検証成功です。最後に通常の復元が HTTP 200 で通ることも確認します。

### 登録を省いた復元

```bash
docker compose exec web bin/rails runner lib/tasks/client_recover_failure.rb
```

クライアント内だけで生成した未登録の鍵で復元を試みます。復元用 options 取得が HTTP 200、復元が HTTP 404・`{"error":"Credential not found"}` なら検証成功です。先に成功ケースを実行する必要はありません。

出力例: [成功時](lib/tasks/sample_result.log) / [2 回実行時](lib/tasks/sample_result_twice.log) / [署名カウンター検証時](lib/tasks/sample_sign_count.log) / [未登録の鍵による失敗時](lib/tasks/sample_failure.log)

## 開発・停止

ソースコードと Gemfile はホストのものを使用します。Gemfile の変更後は次を実行してください。

```bash
docker compose exec web bundle install
docker compose restart web
```

DB と gem は Docker のボリュームに保持されます。ホストの `storage/` とは別で、`docker compose down --volumes` を実行すると削除されます。

設計上の前提・制約は [設計書](doc/design.md) を参照してください。
