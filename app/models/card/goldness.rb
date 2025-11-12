class Card::Goldness < ApplicationRecord
  belongs_to :card, touch: true
end
