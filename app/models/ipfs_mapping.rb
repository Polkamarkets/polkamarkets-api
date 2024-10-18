class IpfsMapping < ApplicationRecord
  validates_presence_of :ipfs_hash, :url
  validates_uniqueness_of :ipfs_hash
end
