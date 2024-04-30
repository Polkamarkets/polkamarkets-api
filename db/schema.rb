# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2024_04_30_111915) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "achievement_tokens", force: :cascade do |t|
    t.bigint "achievement_id", null: false
    t.integer "eth_id", null: false
    t.integer "network_id", null: false
    t.string "image_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["achievement_id"], name: "index_achievement_tokens_on_achievement_id"
  end

  create_table "achievements", force: :cascade do |t|
    t.integer "eth_id", null: false
    t.integer "network_id", null: false
    t.integer "action", null: false
    t.integer "occurrences", null: false
    t.string "image_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "verified", default: false
    t.string "title"
    t.string "description"
    t.index ["eth_id", "network_id"], name: "index_achievements_on_eth_id_and_network_id", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.integer "network_id"
    t.datetime "timestamp"
    t.text "address"
    t.text "action"
    t.text "tx_id"
    t.text "block_number"
    t.float "amount"
    t.float "shares"
    t.integer "market_id"
    t.integer "outcome_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "token_address"
    t.index ["action"], name: "index_activities_on_action"
    t.index ["address"], name: "index_activities_on_address"
    t.index ["market_id"], name: "index_activities_on_market_id"
    t.index ["network_id", "tx_id", "action"], name: "index_activities_on_network_id_and_tx_id_and_action", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "user_id", null: false
    t.bigint "market_id", null: false
    t.bigint "parent_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["market_id"], name: "index_comments_on_market_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "eth_events", force: :cascade do |t|
    t.string "contract_name", null: false
    t.integer "network_id", null: false
    t.string "event", null: false
    t.string "address", null: false
    t.string "block_hash"
    t.integer "block_number", null: false
    t.integer "log_index", null: false
    t.boolean "removed"
    t.string "transaction_hash", null: false
    t.integer "transaction_index"
    t.string "signature"
    t.jsonb "data"
    t.jsonb "raw_data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["address"], name: "index_eth_events_on_address"
    t.index ["block_number"], name: "index_eth_events_on_block_number"
    t.index ["contract_name"], name: "index_eth_events_on_contract_name"
    t.index ["event"], name: "index_eth_events_on_event"
    t.index ["network_id", "transaction_hash", "log_index"], name: "index_eth_events_on_network_id_transaction_hash_log_index", unique: true
    t.index ["network_id"], name: "index_eth_events_on_network_id"
  end

  create_table "eth_events_queries", id: false, force: :cascade do |t|
    t.bigint "eth_event_id", null: false
    t.bigint "eth_query_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["eth_event_id", "eth_query_id"], name: "index_eth_events_queries_on_eth_event_id_and_eth_query_id", unique: true
  end

  create_table "eth_queries", force: :cascade do |t|
    t.string "contract_name", null: false
    t.integer "network_id", null: false
    t.string "event", null: false
    t.string "filter"
    t.integer "last_block_number"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "contract_address", null: false
    t.string "api_url", null: false
    t.index ["contract_name"], name: "index_eth_queries_on_contract_name"
    t.index ["event"], name: "index_eth_queries_on_event"
    t.index ["last_block_number"], name: "index_eth_queries_on_last_block_number"
    t.index ["network_id", "contract_name", "event", "filter", "contract_address", "api_url"], name: "index_eth_queries_on_network_id_cn_ca_api_url_event_filter", unique: true
    t.index ["network_id"], name: "index_eth_queries_on_network_id"
  end

  create_table "group_leaderboards", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug"
    t.string "created_by", null: false
    t.jsonb "users", default: []
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "image_hash"
    t.string "banner_url"
    t.index ["slug"], name: "index_group_leaderboards_on_slug", unique: true
  end

  create_table "market_outcomes", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.string "title", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "eth_market_id"
    t.string "image_url"
    t.index ["market_id", "eth_market_id"], name: "index_market_outcomes_on_market_id_and_eth_market_id", unique: true
    t.index ["market_id"], name: "index_market_outcomes_on_market_id"
  end

  create_table "markets", force: :cascade do |t|
    t.string "title", null: false
    t.string "description"
    t.string "category", null: false
    t.string "subcategory"
    t.datetime "published_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "eth_market_id"
    t.string "image_url"
    t.string "oracle_source"
    t.string "slug"
    t.string "trading_view_symbol"
    t.boolean "verified", default: false
    t.string "banner_url"
    t.integer "network_id", null: false
    t.index ["eth_market_id", "network_id"], name: "index_markets_on_eth_market_id_and_network_id", unique: true
    t.index ["slug"], name: "index_markets_on_slug", unique: true
  end

  create_table "markets_tournaments", id: false, force: :cascade do |t|
    t.bigint "market_id"
    t.bigint "tournament_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["market_id"], name: "index_markets_tournaments_on_market_id"
    t.index ["tournament_id"], name: "index_markets_tournaments_on_tournament_id"
  end

  create_table "portfolios", force: :cascade do |t|
    t.string "eth_address", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "network_id", null: false
    t.index ["eth_address", "network_id"], name: "index_portfolios_on_eth_address_and_network_id", unique: true
  end

  create_table "tournament_groups", force: :cascade do |t|
    t.string "title", null: false
    t.string "description", null: false
    t.string "slug"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "image_url"
    t.string "banner_url"
    t.jsonb "tags", default: []
    t.jsonb "social_urls", default: {}
    t.index ["slug"], name: "index_tournament_groups_on_slug", unique: true
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "title", null: false
    t.string "description", null: false
    t.string "slug"
    t.string "image_url"
    t.integer "network_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "tournament_group_id"
    t.integer "position"
    t.string "rank_by"
    t.text "rules"
    t.jsonb "rewards", default: []
    t.jsonb "topics", default: []
    t.datetime "expires_at"
    t.index ["slug"], name: "index_tournaments_on_slug", unique: true
    t.index ["tournament_group_id"], name: "index_tournaments_on_tournament_group_id"
  end

  create_table "user_operations", force: :cascade do |t|
    t.integer "network_id", null: false
    t.integer "status", default: 0, null: false
    t.string "user_address", null: false
    t.string "user_operation_hash", null: false
    t.jsonb "user_operation", null: false
    t.jsonb "user_operation_data", null: false
    t.string "transaction_hash"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "error_message"
    t.integer "retries", default: 0
    t.index ["network_id", "user_address"], name: "index_user_operations_on_network_id_and_user_address"
    t.index ["user_address"], name: "index_user_operations_on_user_address"
    t.index ["user_operation_hash"], name: "index_user_operations_on_user_operation_hash", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "login_public_key"
    t.string "username"
    t.string "wallet_address"
    t.string "login_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "discord_servers"
    t.string "avatar"
    t.string "raw_email"
    t.string "slug"
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "achievement_tokens", "achievements"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "markets"
  add_foreign_key "comments", "users"
  add_foreign_key "market_outcomes", "markets"
  add_foreign_key "tournaments", "tournament_groups"
end
