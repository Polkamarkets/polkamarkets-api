require 'pagy/extras/items'
require 'pagy/extras/array'
require "pagy/extras/overflow"
require 'pagy/extras/metadata'

Pagy::DEFAULT[:overflow] = :empty_page
Pagy::DEFAULT[:limit] = 50
Pagy::DEFAULT[:items] = 50
Pagy::DEFAULT[:max_items] = 150
Pagy::DEFAULT[:items_extra] = true
