class Card < ApplicationRecord
  include Assignable, Colored, Engageable, Entropy, Eventable,
    Golden, Mentions, Pinnable, Closeable, Readable, Searchable,
    Staged, Statuses, Taggable, Watchable

  belongs_to :collection, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :comments, dependent: :destroy
  has_one_attached :image, dependent: :purge_later

  has_rich_text :description

  before_save :set_default_title, if: :published?
  after_save :handle_collection_change, if: :saved_change_to_collection_id?

  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }
  scope :chronologically, -> { order created_at: :asc, id: :asc }
  scope :latest, -> { order updated_at: :desc, id: :desc }

  scope :indexed_by, ->(index) do
    case index
    when "newest"  then reverse_chronologically
    when "oldest"  then chronologically
    when "latest"  then latest
    when "stalled" then chronologically
    when "closed"  then closed
    end
  end

  def cache_key
    [ super, collection.name ].compact.join("/")
  end

  def card
    self
  end

  private
    def set_default_title
      self.title = "Untitled" if title.blank?
    end

    def handle_collection_change
      transaction do
        old_collection = Collection.find_by(id: collection_id_before_last_save)
        if old_collection.present?
          track_event "collection_changed", particulars: {
            old_collection: old_collection.name,
            new_collection: collection.name
          }
        end
        grant_access_to_assignees unless collection.all_access?
      end
    end

    def grant_access_to_assignees
      collection.accesses.grant_to(assignees)
    end
end
