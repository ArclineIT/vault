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

ActiveRecord::Schema[8.1].define(version: 2026_10_10_100001) do
  create_table "api_key_grants", force: :cascade do |t|
    t.integer "api_key_id", null: false
    t.integer "environment_id", null: false
    t.index ["api_key_id", "environment_id"], name: "index_api_key_grants_on_api_key_id_and_environment_id", unique: true
    t.index ["api_key_id"], name: "index_api_key_grants_on_api_key_id"
    t.index ["environment_id"], name: "index_api_key_grants_on_environment_id"
  end

  create_table "api_keys", force: :cascade do |t|
    t.string "name", null: false
    t.string "prefix", null: false
    t.string "token_digest", null: false
    t.boolean "read_only", default: false, null: false
    t.boolean "all_environments", default: false, null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prefix"], name: "index_api_keys_on_prefix", unique: true
  end

  create_table "audit_entries", force: :cascade do |t|
    t.string "key_prefix", default: "", null: false
    t.string "action", null: false
    t.string "environment_name", default: "", null: false
    t.string "secret_name", default: "", null: false
    t.string "outcome", default: "ok", null: false
    t.string "ip_address", default: "", null: false
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_audit_entries_on_created_at"
  end

  create_table "environments", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_environments_on_name", unique: true
  end

  create_table "secrets", force: :cascade do |t|
    t.integer "environment_id", null: false
    t.string "name", null: false
    t.string "description", default: "", null: false
    t.string "tags", default: "", null: false
    t.binary "ciphertext", null: false
    t.binary "wrapped_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment_id", "name"], name: "index_secrets_on_environment_id_and_name", unique: true
    t.index ["environment_id"], name: "index_secrets_on_environment_id"
  end

  add_foreign_key "api_key_grants", "api_keys", on_delete: :cascade
  add_foreign_key "api_key_grants", "environments", on_delete: :cascade
  add_foreign_key "secrets", "environments", on_delete: :cascade
end
