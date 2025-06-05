module Card::Engageable
  extend ActiveSupport::Concern

  included do
    has_one :engagement, dependent: :destroy, class_name: "Card::Engagement"

    scope :considering, -> { published_or_drafted_by(Current.user).open.where.missing(:engagement) }
    scope :doing,       -> { published.open.joins(:engagement) }

    scope :by_engagement_status, ->(status) do
      case status.to_s
      when "considering" then considering
      when "doing"       then doing.with_golden_first
      end
    end
  end

  def doing?
    open? && published? && engagement.present?
  end

  def considering?
    open? && published? && engagement.blank?
  end

  def engagement_status
    if doing?
      "doing"
    elsif considering?
      "considering"
    end
  end

  def engage
    unless doing?
      transaction do
        reopen
        create_engagement!
      end
    end
  end

  def reconsider
    transaction do
      reopen
      engagement&.destroy
      touch_last_active_at
    end
  end
end
