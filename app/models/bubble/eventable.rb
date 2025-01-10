module Bubble::Eventable
  extend ActiveSupport::Concern

  included do
    after_create -> { track_event :created, creator: creator }
  end

  private
    def track_event(action, creator: Current.user, **particulars)
      event = find_or_capture_event_summary.events.create! action: action, creator: creator, particulars: particulars
      generate_notifications(event)
    end

    def find_or_capture_event_summary
      transaction do
        messages.last&.event_summary || capture(EventSummary.new).event_summary
      end
    end

    def generate_notifications(event)
      Notifier.for(event)&.generate
    end
end
