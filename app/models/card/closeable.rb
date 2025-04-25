module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :closed, -> { joins(:closure) }
    scope :open, -> { where.missing(:closure) }

    scope :recently_closed_first, -> { closed.order("closures.created_at": :desc) }
    scope :in_auto_closing_collection, -> { joins(:collection).merge(Collection.auto_closing) }
    scope :due_to_be_closed, -> { considering.in_auto_closing_collection.where("last_active_at <= DATETIME('now', '-' || auto_close_period || ' seconds')") }

    delegate :auto_closing?, :auto_close_period, to: :collection
  end

  class_methods do
    def auto_close_all_due
      due_to_be_closed.find_each do |card|
        card.close(user: User.system, reason: "Closed")
      end
    end
  end

  def auto_close_at
    last_active_at + auto_close_period if auto_closing? && last_active_at
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end

  def closed_by
    closure&.user
  end

  def closed_at
    closure&.created_at
  end

  def close(user: Current.user, reason: Closure::Reason::FALLBACK_LABEL)
    unless closed?
      transaction do
        create_closure! user: user, reason: reason
        track_event :closed, creator: user
      end
    end
  end

  def reopen
    closure&.destroy
  end
end
