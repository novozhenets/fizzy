class Collection < ApplicationRecord
  include AutoClosing, Accessible, Broadcastable, Filterable, Workflowing

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :cards, dependent: :destroy
  has_many :tags, -> { distinct }, through: :cards
  has_many :events

  scope :alphabetically, -> { order("lower(name)") }
end
