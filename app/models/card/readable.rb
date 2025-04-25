module Card::Readable
  extend ActiveSupport::Concern

  def read_by(user)
    notifications_for(user).tap do |notifications|
      notifications.each(&:read)
    end
  end

  private
    def notifications_for(user)
      user.notifications.unread.where(source: notification_sources)
    end

    def notification_sources
      event_notification_sources + mention_notification_sources
    end

    def event_notification_sources
      events + comment_creation_events
    end

    def comment_creation_events
      Event.where(eventable: comments)
    end

    def mention_notification_sources
      mentions + comment_mentions
    end

    def comment_mentions
      Mention.where(source: comments)
    end

    def comments
      @comments ||= Comment.where(id: messages.comments.pluck(:messageable_id))
    end
end
