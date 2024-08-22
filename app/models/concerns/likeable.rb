module Likeable
  extend ActiveSupport::Concern

  included do
    def update_likes_counter
      self.likes_count = likes.count
      save
    end
  end
end
