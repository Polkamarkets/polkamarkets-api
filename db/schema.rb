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

ActiveRecord::Schema.define(version: 2023_09_06_172742) do

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

  create_table "rewards", force: :cascade do |t|
    t.integer "epoch", null: false
    t.string "timeframe", null: false
    t.string "token_address", null: false
    t.integer "network_id", null: false
    t.jsonb "merkle_tree", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "title", null: false
    t.string "description", null: false
    t.string "slug"
    t.string "image_url"
    t.integer "network_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["slug"], name: "index_tournaments_on_slug", unique: true
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
  end

  add_foreign_key "achievement_tokens", "achievements"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "market_outcomes", "markets"
end
