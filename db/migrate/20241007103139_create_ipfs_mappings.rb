class CreateIpfsMappings < ActiveRecord::Migration[6.0]
  def change
    create_table :ipfs_mappings do |t|
      t.string :ipfs_hash, null: false
      t.string :url, null: false

      t.timestamps
    end

    add_index :ipfs_mappings, :ipfs_hash, unique: true
  end
end
