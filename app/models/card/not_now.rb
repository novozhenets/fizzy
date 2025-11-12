class Card::NotNow < ApplicationRecord
  belongs_to :card, class_name: "::Card", touch: true
  belongs_to :user, optional: true
end
