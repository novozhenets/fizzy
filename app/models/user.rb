class User < ApplicationRecord
  include Accessor, Assignee, Attachable, Configurable,
    Mentionable, Named, Notifiable, Role, Searcher, Watcher
  include Timelined # Depends on Accessor

  has_one_attached :avatar

  belongs_to :account, default: -> { Current.account }
  belongs_to :membership, optional: true

  has_one :identity, through: :membership, disable_joins: true

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card

  delegate :staff?, to: :identity, allow_nil: true

  def deactivate
    transaction do
      accesses.destroy_all
      membership.destroy!
      update! active: false
    end
  end
end
