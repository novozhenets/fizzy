class Card::ActivitySpike < ApplicationRecord
  belongs_to :card, touch: true
end
