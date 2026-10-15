# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_074331) do
  create_table "user_webauthn_credentials", force: :cascade do |t|
    t.string "webauthn_user_id", null: false
    t.string "credential_id", null: false
    t.string "public_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credential_id"], name: "index_user_webauthn_credentials_on_credential_id", unique: true
    t.index ["public_key"], name: "index_user_webauthn_credentials_on_public_key", unique: true
    t.index ["webauthn_user_id"], name: "index_user_webauthn_credentials_on_webauthn_user_id"
  end

  create_table "user_webauthn_identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "webauthn_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_webauthn_identities_on_user_id", unique: true
    t.index ["webauthn_user_id"], name: "index_user_webauthn_identities_on_webauthn_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "user_webauthn_credentials", "user_webauthn_identities", column: "webauthn_user_id", primary_key: "webauthn_user_id"
  add_foreign_key "user_webauthn_identities", "users"
end
