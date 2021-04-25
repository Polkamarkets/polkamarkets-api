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

ActiveRecord::Schema.define(version: 2021_04_23_101840) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "market_outcomes", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.string "title", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "eth_market_id"
    t.index ["market_id", "title"], name: "index_market_outcomes_on_market_id_and_title", unique: true
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
  end

  create_table "portfolios", force: :cascade do |t|
    t.string "eth_address", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["eth_address"], name: "index_portfolios_on_eth_address", unique: true
  end

  add_foreign_key "market_outcomes", "markets"
end
