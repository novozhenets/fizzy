#!/usr/bin/env ruby

require_relative "../config/environment"
require "pathname"
require "optparse"

class Import
  attr_reader :db_path, :untenanted_db_path
  attr_reader :account, :tenant, :mapping

  def initialize(db_path, untenanted_db_path)
    @db_path = Pathname(db_path)
    @untenanted_db_path = Pathname(untenanted_db_path)
    @mapping = nil
  end

  def import_database
    raise "The given database file doesn't exist" unless db_path.exist?

    @mapping = {}

    setup_account

    ActiveRecord::Base.no_touching do
      Event.suppress do
        Current.with(account: account) do
          Webhook.skip_callback(:create, :after, :create_delinquency_tracker!)
          Comment.skip_callback(:create, :after_create_commit, :watch_card_by_creator)
          Mention.skip_callback(:create, :after_create_commit, :watch_source_by_mentionee)
          Mention.skip_callback(:create, :after_create_commit, :notify_recipients)
          Notification.skip_callback(:create, :after_create_commit, :broadcast_unread)
          Notification.skip_callback(:create, :after, :bundle)
          Notification.skip_callback(:create, :after_create_commit, :push_notification)
          Reaction.skip_callback(:create, :after, :register_card_activity)
          Card.skip_callback(:save, :before, :set_default_title)
          Card.skip_callback(:update, :after, :handle_board_change)

          copy_entropies
          copy_users
          copy_boards
          copy_accesses
          copy_columns
          copy_cards
          copy_steps
          copy_comments
          copy_mentions
          copy_reactions
          copy_tags
          copy_watches
          copy_pins
          copy_webhooks
          copy_push_subscriptions
          copy_notifications
          copy_notification_bundles
          copy_filters
          copy_events
        end
      end
    end

    @mapping
  end

  private
    def setup_account
      oldest_admin = import.users.order(id: :asc).where(role: :admin, active: true).first
      raise "No admin user found in the database" unless oldest_admin

      membership = untenanted.memberships.find(oldest_admin.membership_id)
      account = import.accounts.sole

      new_identity = Identity.find_or_create_by!(email_address: membership.identity.email_address)
      new_membership = new_identity.memberships.create!(tenant: account.external_account_id.to_s)

      signup = Signup.new(
        email_address: membership.identity.email_address,
        full_name: oldest_admin.name,
        account_name: account.name,
        identity: new_identity,
        membership_id: new_membership.signed_id(purpose: Signup::MEMBERSHIP_PURPOSE)
      )

      unless signup.complete
        raise "Failed to complete signup: #{signup.errors.full_messages.join(', ')}"
      end

      @tenant = signup.tenant
      @account = signup.account

      old_join_code = import.account_join_codes.sole

      attributes = {
        usage_count: old_join_code.usage_count,
        usage_limit: old_join_code.usage_limit
      }
      attributes[:code] = old_join_code.code unless Account::JoinCode.exist?(code: old_join_code.code)

      account.join_code.update_columns(**attributes)
    end

    def copy_users
      import.users.find_each do |old_user|
        new_membership = nil

        if user.active
          membership = untenanted.memberships.find(old_user.membership_id)
          new_identity = Identity.find_or_create_by!(email_address: identity.email_address)
          new_membership = new_identity.memberships.find_or_create_by!(tenant: tenant)
        end

        new_user = User.find_or_create_by!(account_id: account.id, membership_id: new_membership&.id) do |u|
          u.name = old_user.name
          u.role = old_user.role
          u.active = old_user.active
        end

        old_settings = old_user.settings
        if old_settings
          User::Settings.find_or_create_by!(user_id: new_user.id) do |s|
            s.bundle_email_frequency = old_settings.bundle_email_frequency
            s.timezone_name = old_settings.timezone_name
          end
        end

        mapping[:users] ||= {}
        mapping[:users][old_user.id] = new_user.id
      end
    end

    def copy_boards
      import.boards.find_each do |old_board|
        new_board = Board.create!(
          account_id: account.id,
          creator_id: mapping[:users][old_board.creator_id],
          name: old_board.name,
          all_access: old_board.all_access,
          created_at: old_board.created_at,
          updated_at: old_board.updated_at
        )

        old_publication = old_board.publication
        if old_publication
          Board::Publication.create!(
            board_id: new_board.id,
            key: old_publication.key,
            created_at: old_publication.created_at,
            updated_at: old_publication.updated_at
          )
        end

        mapping[:boards] ||= {}
        mapping[:boards][old_board.id] = new_board.id
      end
    end

    def copy_columns
      import.columns.find_each do |old_column|
        new_column = Column.create!(
          account_id: account.id,
          board_id: mapping[:boards][old_column.board_id],
          name: old_column.name,
          color: old_column.color,
          position: old_column.position,
          created_at: old_column.created_at,
          updated_at: old_column.updated_at
        )

        mapping[:columns] ||= {}
        mapping[:columns][old_column.id] = new_column.id
      end
    end

    def copy_cards
      import.cards.find_each do |old_card|
        new_card = Card.create!(
          account_id: account.id,
          board_id: mapping[:boards][old_card.board_id],
          column_id: old_card.column_id ? mapping[:columns][old_card.column_id] : nil,
          creator_id: mapping[:users][old_card.creator_id],
          title: old_card.title,
          status: old_card.status,
          due_on: old_card.due_on,
          last_active_at: old_card.last_active_at,
          created_at: old_card.created_at,
          updated_at: old_card.updated_at
        )

        copy_rich_text(old_card, new_card, "Card", "description")
        copy_attachment(old_card, new_card, "Card", "image")

        old_activity_spike = old_card.activity_spike
        if old_activity_spike
          Card::ActivitySpike.create!(
            card_id: new_card.id,
            created_at: old_activity_spike.created_at,
            updated_at: old_activity_spike.updated_at
          )
        end

        old_engagement = old_card.engagement
        if old_engagement
          Card::Engagement.create!(
            card_id: new_card.id,
            status: old_engagement.status,
            created_at: old_engagement.created_at,
            updated_at: old_engagement.updated_at
          )
        end

        old_goldness = old_card.goldness
        if old_goldness
          Card::Goldness.create!(
            card_id: new_card.id,
            created_at: old_goldness.created_at,
            updated_at: old_goldness.updated_at
          )
        end

        old_not_now = old_card.not_now
        if old_not_now
          Card::NotNow.create!(
            card_id: new_card.id,
            user_id: old_not_now.user_id ? mapping[:users][old_not_now.user_id] : nil,
            created_at: old_not_now.created_at,
            updated_at: old_not_now.updated_at
          )
        end

        old_card.assignments.each do |old_assignment|
          Assignment.create!(
            account_id: account.id,
            card_id: new_card.id,
            assignee_id: mapping[:users][old_assignment.assignee_id],
            assigner_id: mapping[:users][old_assignment.assigner_id],
            created_at: old_assignment.created_at,
            updated_at: old_assignment.updated_at
          )
        end

        old_closure = old_card.closure
        if old_closure
          Closure.create!(
            account_id: account.id,
            card_id: new_card.id,
            user_id: old_closure.user_id ? mapping[:users][old_closure.user_id] : nil,
            created_at: old_closure.created_at,
            updated_at: old_closure.updated_at
          )
        end

        mapping[:cards] ||= {}
        mapping[:cards][old_card.id] = new_card.id
      end
    end

    def copy_steps
      import.steps.find_each do |old_step|
        Step.create!(
          account_id: account.id,
          card_id: mapping[:cards][old_step.card_id],
          content: old_step.content,
          completed: old_step.completed,
          created_at: old_step.created_at,
          updated_at: old_step.updated_at
        )
      end
    end

    def copy_comments
      import.comments.find_each do |old_comment|
        new_comment = Comment.create!(
          account_id: account.id,
          card_id: mapping[:cards][old_comment.card_id],
          creator_id: mapping[:users][old_comment.creator_id],
          created_at: old_comment.created_at,
          updated_at: old_comment.updated_at
        )

        copy_rich_text(old_comment, new_comment, "Comment", "body")

        mapping[:comments] ||= {}
        mapping[:comments][old_comment.id] = new_comment.id
      end
    end

    def copy_mentions
      import.mentions.find_each do |old_mention|
        new_mention = Mention.create!(
          account_id: account.id,
          source_type: old_mention.source_type,
          source_id: mapping[old_mention.source_type.tableize.to_sym][old_mention.source_id],
          mentioner_id: mapping[:users][old_mention.mentioner_id],
          mentionee_id: mapping[:users][old_mention.mentionee_id],
          created_at: old_mention.created_at,
          updated_at: old_mention.updated_at
        )

        mapping[:mentions] ||= {}
        mapping[:mentions][old_mention.id] = new_mention.id
      end
    end

    def copy_accesses
      import.accesses.find_each do |old_access|
        new_access = Access.create!(
          account_id: account.id,
          board_id: mapping[:boards][old_access.board_id],
          user_id: mapping[:users][old_access.user_id],
          involvement: old_access.involvement,
          accessed_at: old_access.accessed_at,
          created_at: old_access.created_at,
          updated_at: old_access.updated_at
        )

        mapping[:accesses] ||= {}
        mapping[:accesses][old_access.id] = new_access.id
      end
    end

    def copy_notifications
      import.notifications.find_each do |old_notification|
        new_notification = Notification.create!(
          account_id: account.id,
          user_id: mapping[:users][old_notification.user_id],
          creator_id: old_notification.creator_id ? mapping[:users][old_notification.creator_id] : nil,
          source_type: old_notification.source_type,
          source_id: mapping[old_notification.source_type.tableize.to_sym][old_notification.source_id],
          read_at: old_notification.read_at,
          created_at: old_notification.created_at,
          updated_at: old_notification.updated_at
        )

        mapping[:notifications] ||= {}
        mapping[:notifications][old_notification.id] = new_notification.id
      end
    end

    def copy_notification_bundles
      import.notification_bundles.find_each do |old_bundle|
        new_bundle = Notification::Bundle.create!(
          account_id: account.id,
          user_id: mapping[:users][old_bundle.user_id],
          status: old_bundle.status,
          starts_at: old_bundle.starts_at,
          ends_at: old_bundle.ends_at,
          created_at: old_bundle.created_at,
          updated_at: old_bundle.updated_at
        )

        mapping[:notification_bundles] ||= {}
        mapping[:notification_bundles][old_bundle.id] = new_bundle.id
      end
    end

    def copy_entropies
      import.entropies.find_each do |old_entropy|
        container_id = case old_entropy.container_type
        when "Account" then account.id
        when "Board" then mapping[:boards][old_entropy.container_id]
        when "Card" then mapping[:cards][old_entropy.container_id]
        else next
        end

        Entropy.create!(
          container_type: old_entropy.container_type,
          container_id: container_id,
          auto_postpone_period: old_entropy.auto_postpone_period,
          created_at: old_entropy.created_at,
          updated_at: old_entropy.updated_at
        )
      end
    end

    def copy_filters
      import.filters.find_each do |old_filter|
        new_filter = Filter.create!(
          account_id: account.id,
          creator_id: mapping[:users][old_filter.creator_id],
          fields: old_filter.fields,
          params_digest: old_filter.params_digest,
          created_at: old_filter.created_at,
          updated_at: old_filter.updated_at
        )

        import.assignees_filters.where(filter_id: old_filter.id).each do |join|
          AssigneesFilter.find_or_create_by!(filter_id: new_filter.id, user_id: mapping[:users][join.user_id])
        end

        import.assigners_filters.where(filter_id: old_filter.id).each do |join|
          AssignersFilter.find_or_create_by!(filter_id: new_filter.id, user_id: mapping[:users][join.user_id])
        end

        import.boards_filters.where(filter_id: old_filter.id).each do |join|
          BoardsFilter.find_or_create_by!(filter_id: new_filter.id, board_id: mapping[:boards][join.board_id])
        end

        import.closers_filters.where(filter_id: old_filter.id).each do |join|
          ClosersFilter.find_or_create_by!(filter_id: new_filter.id, user_id: mapping[:users][join.user_id])
        end

        import.creators_filters.where(filter_id: old_filter.id).each do |join|
          CreatorsFilter.find_or_create_by!(filter_id: new_filter.id, user_id: mapping[:users][join.user_id])
        end

        import.filters_tags.where(filter_id: old_filter.id).each do |join|
          FiltersTag.find_or_create_by!(filter_id: new_filter.id, tag_id: mapping[:tags][join.tag_id])
        end

        mapping[:filters] ||= {}
        mapping[:filters][old_filter.id] = new_filter.id
      end
    end

    def copy_events
      import.events.find_each do |old_event|
        new_event = Event.create!(
          account_id: account.id,
          board_id: mapping[:boards][old_event.board_id],
          creator_id: mapping[:users][old_event.creator_id],
          eventable_type: old_event.eventable_type,
          eventable_id: mapping[old_event.eventable_type.tableize.to_sym][old_event.eventable_id],
          action: old_event.action,
          particulars: old_event.particulars,
          created_at: old_event.created_at,
          updated_at: old_event.updated_at
        )

        mapping[:events] ||= {}
        mapping[:events][old_event.id] = new_event.id
      end
    end

    def copy_rich_text(old_record, new_record, record_type, name)
      old_rich_text = import.rich_texts.find_by(record_type: record_type, record_id: old_record.id, name: name)
      return unless old_rich_text

      new_rich_text = ActionText::RichText.create!(
        record: new_record,
        name: name,
        body: old_rich_text.body,
        created_at: old_rich_text.created_at,
        updated_at: old_rich_text.updated_at
      )

      mapping[:rich_text] ||= {}
      mapping[:rich_text][old_rich_text.id] = new_rich_text.id
    end

    def copy_attachment(old_record, new_record, record_type, name)
      old_attachment = import.attachments.find_by(record_type: record_type, record_id: old_record.id, name: name)
      return unless old_attachment

      old_blob = import.blobs.find(old_attachment.blob_id)

      new_blob = ActiveStorage::Blob.find_or_create_by!(
        key: old_blob.key,
        filename: old_blob.filename,
        content_type: old_blob.content_type,
        metadata: old_blob.metadata,
        service_name: old_blob.service_name,
        byte_size: old_blob.byte_size,
        checksum: old_blob.checksum,
        created_at: old_blob.created_at
      )

      mapping[:blobs] ||= {}
      mapping[:blobs][old_blob.id] = new_blob.id

      new_attachment = ActiveStorage::Attachment.find_or_create_by!(
        name: name,
        record: new_record,
        blob: new_blob,
        created_at: old_attachment.created_at
      )

      mapping[:attachments] ||= {}
      mapping[:attachments][old_attachment.id] = new_attachment.id
    end

    def copy_reactions
      import.reactions.find_each do |old_reaction|
        new_reaction = Reaction.create!(
          account_id: account.id,
          comment_id: mapping[:comments][old_reaction.comment_id],
          reacter_id: mapping[:users][old_reaction.reacter_id],
          content: old_reaction.content,
          created_at: old_reaction.created_at,
          updated_at: old_reaction.updated_at
        )

        mapping[:reactions] ||= {}
        mapping[:reactions][old_reaction.id] = new_reaction.id
      end
    end

    def copy_tags
      import.tags.find_each do |old_tag|
        new_tag = Tag.find_or_create_by!(title: old_tag.title) do |t|
          t.account_id = account.id
          t.created_at = old_tag.created_at
          t.updated_at = old_tag.updated_at
        end

        mapping[:tags] ||= {}
        mapping[:tags][old_tag.id] = new_tag.id
      end

      import.taggings.find_each do |old_tagging|
        new_tagging = Tagging.create!(
          account_id: account.id,
          tag_id: mapping[:tags][old_tagging.tag_id],
          card_id: mapping[:cards][old_tagging.card_id],
          created_at: old_tagging.created_at,
          updated_at: old_tagging.updated_at
        )

        mapping[:taggings] ||= {}
        mapping[:taggings][old_tagging.id] = new_tagging.id
      end
    end

    def copy_watches
      import.watches.find_each do |old_watch|
        new_watch = Watch.create!(
          account_id: account.id,
          user_id: mapping[:users][old_watch.user_id],
          card_id: mapping[:cards][old_watch.card_id],
          watching: old_watch.watching,
          created_at: old_watch.created_at,
          updated_at: old_watch.updated_at
        )

        mapping[:watches] ||= {}
        mapping[:watches][old_watch.id] = new_watch.id
      end
    end

    def copy_pins
      import.pins.find_each do |old_pin|
        new_pin = Pin.create!(
          account_id: account.id,
          user_id: mapping[:users][old_pin.user_id],
          card_id: mapping[:cards][old_pin.card_id],
          created_at: old_pin.created_at,
          updated_at: old_pin.updated_at
        )

        mapping[:pins] ||= {}
        mapping[:pins][old_pin.id] = new_pin.id
      end
    end

    def copy_webhooks
      import.webhooks.find_each do |old_webhook|
        new_webhook = Webhook.create!(
          account_id: account.id,
          board_id: mapping[:boards][old_webhook.board_id],
          name: old_webhook.name,
          url: old_webhook.url,
          signing_secret: old_webhook.signing_secret,
          subscribed_actions: old_webhook.subscribed_actions,
          active: old_webhook.active,
          created_at: old_webhook.created_at,
          updated_at: old_webhook.updated_at
        )

        mapping[:webhooks] ||= {}
        mapping[:webhooks][old_webhook.id] = new_webhook.id

        old_tracker = import.webhook_delinquency_trackers.find_by(webhook_id: old_webhook.id)
        Webhook::DelinquencyTracker.create!(
          webhook_id: new_webhook.id,
          consecutive_failures_count: old_tracker.consecutive_failures_count,
          first_failure_at: old_tracker.first_failure_at,
          created_at: old_tracker.created_at,
          updated_at: old_tracker.updated_at
        )
      end

      import.webhook_deliveries.find_each do |old_delivery|
        new_delivery = Webhook::Delivery.create!(
          webhook_id: mapping[:webhooks][old_delivery.webhook_id],
          event_id: mapping[:events][old_delivery.event_id],
          state: old_delivery.state,
          request: old_delivery.request,
          response: old_delivery.response,
          created_at: old_delivery.created_at,
          updated_at: old_delivery.updated_at
        )

        mapping[:webhook_deliveries] ||= {}
        mapping[:webhook_deliveries][old_delivery.id] = new_delivery.id
      end
    end

    def copy_push_subscriptions
      import.push_subscriptions.find_each do |old_subscription|
        new_subscription = Push::Subscription.create!(
          account_id: account.id,
          user_id: mapping[:users][old_subscription.user_id],
          endpoint: old_subscription.endpoint,
          p256dh_key: old_subscription.p256dh_key,
          auth_key: old_subscription.auth_key,
          user_agent: old_subscription.user_agent,
          created_at: old_subscription.created_at,
          updated_at: old_subscription.updated_at
        )

        mapping[:push_subscriptions] ||= {}
        mapping[:push_subscriptions][old_subscription.id] = new_subscription.id
      end
    end

    def import
      @import ||= Models.new(db_path)
    rescue => e
      $stderr.puts e.backtrace.join("\n") if ENV["DEBUG"]
      raise "Couldn't open the given database: #{e}"
    end

    def untenanted
      @untenanted ||= Models.new(untenanted_db_path)
    rescue => e
      $stderr.puts e.backtrace.join("\n") if ENV["DEBUG"]
      raise "Couldn't open the given untenanted database: #{e}"
    end
end

class Models
  attr_reader :application_record

  def initialize(db_path)
    const_name = "ImportBase#{db_path.hash.abs}"

    if self.class.const_defined?(const_name)
      @application_record = self.class.const_get(const_name)
    else
      @application_record = Class.new(ActiveRecord::Base) do
        self.abstract_class = true

        def self.models
          const_get("MODELS")
        end

        delegate :models, to: :class
      end
      self.class.const_set(const_name, @application_record)
    end

    @application_record.establish_connection adapter: "sqlite3", database: db_path
    @application_record.const_set("MODELS", self)
  end

  def identities
    @identities ||= Class.new(application_record) do
      self.table_name = "identities"
    end
  end

  def memberships
    @memberships ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "memberships"

        def identity
          @identity ||= models.identities.find_by(id: identity_id)
        end
      end
    end
  end

  def accounts
    @accounts ||= Class.new(application_record) do
      self.table_name = "accounts"
    end
  end

  def account_join_codes
    @account_join_codes ||= Class.new(application_record) do
      self.table_name = "account_join_codes"
    end
  end

  def users
    @users ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "users"

        def settings
          @settings ||= models.user_settings.find_by(user_id: id)
        end
      end
    end
  end

  def boards
    @boards ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "boards"

        def publication
          @publication ||= models.board_publications.find_by(board_id: id)
        end
      end
    end
  end

  def columns
    @columns ||= Class.new(application_record) do
      self.table_name = "columns"
    end
  end

  def cards
    @cards ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "cards"

        def activity_spike
          @activity_spike ||= models.card_activity_spikes.find_by(card_id: id)
        end

        def engagement
          @engagement ||= models.card_engagements.find_by(card_id: id)
        end

        def goldness
          @goldness ||= models.card_goldnesses.find_by(card_id: id)
        end

        def not_now
          @not_now ||= models.card_not_nows.find_by(card_id: id)
        end

        def assignments
          models.assignments.where(card_id: id)
        end

        def closure
          @closure ||= models.closures.find_by(card_id: id)
        end
      end
    end
  end

  def comments
    @comments ||= Class.new(application_record) do
      self.table_name = "comments"
    end
  end

  def steps
    @steps ||= Class.new(application_record) do
      self.table_name = "steps"
    end
  end

  def reactions
    @reactions ||= Class.new(application_record) do
      self.table_name = "reactions"
    end
  end

  def tags
    @tags ||= Class.new(application_record) do
      self.table_name = "tags"
    end
  end

  def taggings
    @taggings ||= Class.new(application_record) do
      self.table_name = "taggings"
    end
  end

  def watches
    @watches ||= Class.new(application_record) do
      self.table_name = "watches"
    end
  end

  def pins
    @pins ||= Class.new(application_record) do
      self.table_name = "pins"
    end
  end

  def webhooks
    @webhooks ||= Class.new(application_record) do
      self.table_name = "webhooks"
    end
  end

  def webhook_deliveries
    @webhook_deliveries ||= Class.new(application_record) do
      self.table_name = "webhook_deliveries"
    end
  end

  def webhook_delinquency_trackers
    @webhook_delinquency_trackers ||= Class.new(application_record) do
      self.table_name = "webhook_delinquency_trackers"
    end
  end

  def push_subscriptions
    @push_subscriptions ||= Class.new(application_record) do
      self.table_name = "push_subscriptions"
    end
  end

  def assignments
    @assignments ||= Class.new(application_record) do
      self.table_name = "assignments"
    end
  end

  def closures
    @closures ||= Class.new(application_record) do
      self.table_name = "closures"
    end
  end

  def accesses
    @accesses ||= Class.new(application_record) do
      self.table_name = "accesses"
    end
  end

  def events
    @events ||= Class.new(application_record) do
      self.table_name = "events"
    end
  end

  def rich_texts
    @rich_texts ||= Class.new(application_record) do
      self.table_name = "action_text_rich_texts"
    end
  end

  def attachments
    @attachments ||= Class.new(application_record) do
      self.table_name = "active_storage_attachments"
    end
  end

  def blobs
    @blobs ||= Class.new(application_record) do
      self.table_name = "active_storage_blobs"
    end
  end

  def user_settings
    @user_settings ||= Class.new(application_record) do
      self.table_name = "user_settings"
    end
  end

  def board_publications
    @board_publications ||= Class.new(application_record) do
      self.table_name = "board_publications"
    end
  end

  def card_activity_spikes
    @card_activity_spikes ||= Class.new(application_record) do
      self.table_name = "card_activity_spikes"
    end
  end

  def card_engagements
    @card_engagements ||= Class.new(application_record) do
      self.table_name = "card_engagements"
    end
  end

  def card_goldnesses
    @card_goldnesses ||= Class.new(application_record) do
      self.table_name = "card_goldnesses"
    end
  end

  def card_not_nows
    @card_not_nows ||= Class.new(application_record) do
      self.table_name = "card_not_nows"
    end
  end

  def mentions
    @mentions ||= Class.new(application_record) do
      self.table_name = "mentions"
    end
  end

  def notifications
    @notifications ||= Class.new(application_record) do
      self.table_name = "notifications"
    end
  end

  def notification_bundles
    @notification_bundles ||= Class.new(application_record) do
      self.table_name = "notification_bundles"
    end
  end

  def entropies
    @entropies ||= Class.new(application_record) do
      self.table_name = "entropies"
    end
  end

  def filters
    @filters ||= Class.new(application_record) do
      self.table_name = "filters"
    end
  end

  def assignees_filters
    @assignees_filters ||= Class.new(application_record) do
      self.table_name = "assignees_filters"
    end
  end

  def assigners_filters
    @assigners_filters ||= Class.new(application_record) do
      self.table_name = "assigners_filters"
    end
  end

  def boards_filters
    @boards_filters ||= Class.new(application_record) do
      self.table_name = "boards_filters"
    end
  end

  def closers_filters
    @closers_filters ||= Class.new(application_record) do
      self.table_name = "closers_filters"
    end
  end

  def creators_filters
    @creators_filters ||= Class.new(application_record) do
      self.table_name = "creators_filters"
    end
  end

  def filters_tags
    @filters_tags ||= Class.new(application_record) do
      self.table_name = "filters_tags"
    end
  end
end

options = {}

parser = OptionParser.new do |parser|
  parser.banner = "Usage: #{$PROGRAM_NAME} <db_path> <untenanted_db_path>"

  parser.on("-h", "--help", "Show this help message") do
    puts parser
    exit
  end
end

parser.parse!

db_path = ARGV[0]
untenanted_db_path = ARGV[1]

if db_path.nil? || untenanted_db_path.nil?
  $stderr.puts "Error: both db_path and untenanted_db_path are required"
  $stderr.puts
  $stderr.puts parser
  exit 1
end

begin
  Import.new(db_path, untenanted_db_path).import_database
rescue => e
  $stderr.puts "Error: #{e.message}"
  $stderr.puts e.backtrace.join("\n") if ENV["DEBUG"]
  exit 1
end
