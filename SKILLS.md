# SKILLS for AI Agents

This document provides AI agents with specific skills and patterns for working effectively with the Fizzy codebase. It complements [AGENTS.md](AGENTS.md) (architecture overview) and [STYLE.md](STYLE.md) (code style guidelines).

---

## Table of Contents

1. [Model Development Skills](#model-development-skills)
2. [Controller Development Skills](#controller-development-skills)
3. [Testing Skills](#testing-skills)
4. [Background Job Skills](#background-job-skills)
5. [Real-Time Update Skills](#real-time-update-skills)
6. [Multi-Tenancy Skills](#multi-tenancy-skills)
7. [Authentication & Authorization Skills](#authentication--authorization-skills)
8. [Search Skills](#search-skills)
9. [Migration Skills](#migration-skills)
10. [Debugging Skills](#debugging-skills)

---

## Model Development Skills

### SKILL: Using Concerns for Feature Composition

**When**: Adding new functionality to models that could be reused or logically separated.

**Pattern**: Extract feature into a concern rather than adding directly to model.

```ruby
# app/models/card/closeable.rb
module Card::Closeable
  extend ActiveSupport::Concern
  
  included do
    scope :closed, -> { where.not(closed_at: nil) }
    scope :open, -> { where(closed_at: nil) }
  end
  
  def close
    update!(closed_at: Time.current)
  end
  
  def reopen
    update!(closed_at: nil)
  end
  
  def closed?
    closed_at.present?
  end
end

# app/models/card.rb
class Card < ApplicationRecord
  include Closeable
  # ... other concerns
end
```

**Key Points**:
- Concerns live in `app/models/<model_name>/<concern_name>.rb`
- Use `extend ActiveSupport::Concern` for DSL features
- Group related scopes, validations, and methods
- Keep concerns focused on a single responsibility

**Common Concern Types**:
- **Stateful** (Closeable, Triageable) - Lifecycle management
- **Associative** (Assignable, Watchable) - Relationship handling
- **Behavioral** (Eventable, Broadcastable) - Action tracking
- **Data** (Searchable, Exportable) - Data transformation

---

### SKILL: Event-Driven Actions with Eventable

**When**: Recording user actions or system changes that need audit trails, notifications, or webhooks.

**Pattern**: Include `Eventable` and define action methods that create events.

```ruby
module Card::Closeable
  include Eventable
  
  def close
    # Update the record
    update!(closed_at: Time.current)
    
    # Record the event
    record_event(:closed, creator: Current.user)
  end
end
```

**Key Points**:
- `record_event(action, creator:, particulars: {})` creates Event records
- Events automatically trigger notifications, webhooks, and activity timeline
- Particulars hash stores action-specific data (e.g., `{ from: old_value, to: new_value }`)
- Events are created in `after_commit` hooks to ensure transaction success

**Common Event Actions**:
- `:created`, `:updated`, `:destroyed`
- `:closed`, `:reopened`, `:postponed`
- `:assigned`, `:unassigned`
- `:commented`, `:mentioned`
- `:moved` (with from/to column particulars)

---

### SKILL: Async Method Pattern (_later/_now)

**When**: Actions need background processing (emails, webhooks, heavy computation).

**Pattern**: Pair `_later` (enqueues job) with `_now` (synchronous implementation).

```ruby
module Event::Relaying
  extend ActiveSupport::Concern
  
  included do
    after_create_commit :relay_later
  end
  
  def relay_later
    Event::RelayJob.perform_later(self)
  end
  
  def relay_now
    # Actual webhook delivery logic
    webhooks.each do |webhook|
      deliver_to_webhook(webhook)
    end
  end
end

# app/jobs/event/relay_job.rb
class Event::RelayJob < ApplicationJob
  def perform(event)
    event.relay_now
  end
end
```

**Key Points**:
- `_later` methods enqueue jobs, typically in callbacks
- `_now` methods contain the actual logic
- Keep job classes thin - delegate to model methods
- `Current.account` is automatically preserved across job execution

---

### SKILL: Scoping by Account for Multi-Tenancy

**When**: Querying or creating records that belong to an account.

**Pattern**: Always scope queries through `Current.account` or explicit account association.

```ruby
# Good - Scoped through account
class CardsController < ApplicationController
  def index
    @cards = Current.account.cards.where(board: @board)
  end
  
  def create
    @card = Current.account.cards.create!(card_params)
  end
end

# Bad - Bypasses account scoping (SECURITY ISSUE)
@card = Card.find(params[:id])  # Could access any account's card!

# Good - Scoped through account
@card = Current.account.cards.find(params[:id])
```

**Key Points**:
- Never use unscoped model queries in controllers
- All models have `account_id` foreign key
- Violations are security vulnerabilities (cross-tenant data access)
- Use `Current.account` which is set by `AccountSlug::Extractor` middleware

---

### SKILL: UUID Primary Keys Pattern

**When**: Creating migrations for new tables.

**Pattern**: Use UUID primary keys with base36 encoding.

```ruby
class CreateWidgets < ActiveRecord::Migration[8.0]
  def change
    create_table :widgets, id: :string, limit: 25 do |t|
      t.references :account, null: false, foreign_key: true, type: :string, limit: 25
      t.string :name, null: false
      
      t.timestamps
    end
    
    add_index :widgets, [:account_id, :name], unique: true
  end
end
```

**Key Points**:
- Use `id: :string, limit: 25` for all new tables
- Foreign keys are also `type: :string, limit: 25`
- UUIDs are generated automatically (UUIDv7, base36-encoded)
- Maintains chronological ordering for `.first`/`.last`

---

### SKILL: Turbo Broadcasts for Real-Time Updates

**When**: Model changes should reflect immediately in UI without page refresh.

**Pattern**: Use `broadcasts_refreshes` or explicit broadcast methods.

```ruby
# Simple automatic refresh
class Card < ApplicationRecord
  broadcasts_refreshes
end

# Custom targeted broadcasts
module Card::Broadcastable
  def broadcast_moved
    broadcast_replace_later_to(
      [board, :cards],
      target: "card_#{id}",
      partial: "cards/card",
      locals: { card: self }
    )
  end
end
```

**Key Points**:
- `broadcasts_refreshes` - Simplest option, refreshes dependent elements
- `broadcast_replace_later_to` - Replace specific element
- `broadcast_prepend_later_to` - Add to beginning of collection
- `broadcast_remove_to` - Remove element
- Broadcasts automatically run after commit
- Target format: `[streamable_object, :stream_name]`

---

## Controller Development Skills

### SKILL: Thin Controllers with REST Resources

**When**: Adding new actions or endpoints.

**Pattern**: Map actions to CRUD operations; introduce new resources for non-CRUD actions.

```ruby
# Bad - Custom action
resources :cards do
  post :close
  post :reopen
end

# Good - New resource
resources :cards do
  resource :closure, only: [:create, :destroy]
end

# Controller
class Cards::ClosuresController < ApplicationController
  def create
    @card.close
    redirect_to @card
  end
  
  def destroy
    @card.reopen
    redirect_to @card
  end
end
```

**Key Points**:
- Controllers directly invoke model methods
- No service objects unless complexity demands it
- Each custom action becomes a separate resource
- Use singular `resource` for resources without IDs (like toggles)

---

### SKILL: Authorization with Before Actions

**When**: Controllers need access control.

**Pattern**: Use before actions to load and authorize resources.

```ruby
class Cards::CommentsController < ApplicationController
  before_action :set_card
  before_action :authorize_access
  
  def create
    @comment = @card.comments.create!(comment_params)
    redirect_to @card
  end
  
  private
    def set_card
      @card = Current.account.cards.find(params[:card_id])
    end
    
    def authorize_access
      head :forbidden unless Current.user.can_access?(@card.board)
    end
end
```

**Key Points**:
- Always load through `Current.account` for security
- Check board access via `Current.user.can_access?(board)`
- Use `head :forbidden` for authorization failures
- Load parent resources in `before_action :set_<resource>`

---

### SKILL: Strong Parameters Pattern

**When**: Accepting user input in controllers.

**Pattern**: Use strong parameters with explicit permit lists.

```ruby
class CardsController < ApplicationController
  def create
    @card = @board.cards.create!(card_params)
  end
  
  private
    def card_params
      params.require(:card).permit(:title, :description, :color_id)
    end
end
```

**Key Points**:
- Always use `params.require(:key).permit(:allowed_fields)`
- Never permit `params` directly
- Define `_params` methods as private
- Keep permit lists explicit and minimal

---

## Testing Skills

### SKILL: Test Structure and Organization

**When**: Writing tests for new features.

**Pattern**: Mirror app structure; use appropriate test types.

```
test/
├── models/
│   ├── card_test.rb                    # Unit tests for Card model
│   └── card/
│       └── closeable_test.rb           # Tests for Card::Closeable concern
├── controllers/
│   └── cards/
│       └── closures_controller_test.rb # Controller integration tests
├── jobs/
│   └── event/
│       └── relay_job_test.rb           # Job tests
└── system/
    └── cards/
        └── closing_test.rb              # End-to-end system tests
```

**Test Types**:
- **Unit** (`test/models/`) - Fast, isolated model logic
- **Controller** (`test/controllers/`) - Request/response integration
- **Job** (`test/jobs/`) - Background job execution
- **System** (`test/system/`) - Full browser-based E2E with Capybara

---

### SKILL: Fixture-Based Testing

**When**: Setting up test data.

**Pattern**: Use fixtures for consistent test data; access via symbol.

```ruby
# test/fixtures/cards.yml
david_todo:
  account: company
  board: triage
  title: "Fix bug"
  creator: david
  number: 1

# test/models/card_test.rb
class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:david_todo)
    Current.session = sessions(:david)
  end
  
  test "closes with timestamp" do
    @card.close
    assert_not_nil @card.closed_at
  end
end
```

**Key Points**:
- All fixtures loaded automatically in tests
- Access via `model_name(:fixture_name)`
- Fixtures use UUIDs for deterministic ordering
- Set `Current.session` in setup for authentication context
- Use `Current.account` for scoped queries

---

### SKILL: Testing Broadcasts

**When**: Testing Turbo broadcast behavior.

**Pattern**: Use `assert_broadcasts` to verify real-time updates.

```ruby
test "closing card broadcasts update" do
  assert_broadcasts(@card, :update) do
    @card.close
  end
end

test "creates card and prepends to board" do
  assert_broadcasts_to([@board, :cards], :prepend) do
    @board.cards.create!(title: "New", creator: @user)
  end
end
```

**Key Points**:
- `assert_broadcasts(model, action)` - Tests model broadcasts
- `assert_broadcasts_to(stream, action)` - Tests stream broadcasts
- Common actions: `:update`, `:prepend`, `:remove`
- Broadcasts happen after commit, so wrap in transaction or use `perform_enqueued_jobs`

---

### SKILL: Testing Background Jobs

**When**: Testing async behavior.

**Pattern**: Use `perform_enqueued_jobs` or test jobs directly.

```ruby
# Test job is enqueued
test "relays event asynchronously" do
  assert_enqueued_with(job: Event::RelayJob) do
    @event.relay_later
  end
end

# Test job execution
test "relay job delivers to webhooks" do
  perform_enqueued_jobs do
    @event.relay_later
    assert_equal 1, @webhook.deliveries.count
  end
end

# Test job directly
class Event::RelayJobTest < ActiveJob::TestCase
  test "performs relay" do
    @event.expects(:relay_now).once
    Event::RelayJob.perform_now(@event)
  end
end
```

**Key Points**:
- Use `assert_enqueued_with(job: JobClass)` to test enqueuing
- Use `perform_enqueued_jobs` to execute jobs in tests
- Use Mocha's `expects` for stubbing (available via test_helper)
- Jobs automatically preserve `Current.account`

---

### SKILL: System Test with Capybara

**When**: Testing full user workflows through the browser.

**Pattern**: Use Capybara DSL with explicit waits.

```ruby
class ClosingCardsTest < ApplicationSystemTestCase
  setup do
    @user = users(:david)
    sign_in_as(@user)
  end
  
  test "closing a card" do
    @card = cards(:david_todo)
    visit card_path(@card)
    
    click_button "Close"
    
    assert_text "Card closed"
    assert_selector ".card--closed"
  end
  
  private
    def sign_in_as(user)
      visit new_session_path
      fill_in "Email", with: user.identity.email_address
      click_button "Sign in"
      # Magic link auth - simulate by setting session directly
      post session_path, params: { magic_link_token: user.magic_links.create!.token }
    end
end
```

**Key Points**:
- System tests use headless Chrome via Selenium
- Use `assert_selector` and `assert_text` for UI verification
- Use `visit`, `click_button`, `fill_in` for interactions
- Handle auth with helper methods or session manipulation
- Tests are slower - use sparingly for critical paths

---

## Background Job Skills

### SKILL: Creating Recurring Jobs

**When**: Adding scheduled background tasks.

**Pattern**: Define in `config/recurring.yml` with Solid Queue format.

```yaml
# config/recurring.yml
production:
  cleanup_old_exports:
    class: Export::CleanupJob
    schedule: every day at 3am
    queue: background
  
  deliver_bundled_notifications:
    class: Notification::DeliveryJob
    schedule: every 30 minutes
    queue: notifications
```

**Key Points**:
- Uses Solid Queue's recurring job syntax
- Schedule options: `every X minutes`, `every day at TIME`, cron expressions
- Specify queue for prioritization
- Jobs must be idempotent (safe to run multiple times)

---

### SKILL: Job Prioritization with Queues

**When**: Different jobs have different urgency levels.

**Pattern**: Use named queues and configure priorities.

```ruby
# High priority - user-facing
class Event::RelayJob < ApplicationJob
  queue_as :webhooks
end

# Lower priority - background maintenance
class Export::CleanupJob < ApplicationJob
  queue_as :background
end

# config/recurring.yml
production:
  queues:
    - [webhooks, 10]      # Process 10 workers
    - [default, 5]        # Process 5 workers
    - [background, 2]     # Process 2 workers
```

**Key Points**:
- Default queue is `:default`
- Use `queue_as :name` in job class
- Higher worker count = more throughput
- Monitor via Mission Control::Jobs

---

## Real-Time Update Skills

### SKILL: Broadcasting to Multiple Streams

**When**: An update affects multiple views or users.

**Pattern**: Broadcast to multiple streams in one action.

```ruby
module Card::Assignable
  def assign(user)
    assignments.create!(user: user)
    record_event(:assigned, creator: Current.user, particulars: { user_id: user.id })
    
    # Broadcast to board stream (all viewers)
    broadcast_replace_later_to([board, :cards], target: dom_id(self))
    
    # Broadcast to assignee's personal stream
    broadcast_prepend_later_to([user, :assigned_cards], target: "assigned_cards")
  end
end
```

**Key Points**:
- Multiple broadcasts in single action for different audiences
- Use array `[object, :stream_name]` for stream targeting
- Each user/board/resource can have multiple named streams
- Streams are automatically namespaced by account

---

### SKILL: Conditional Broadcasting

**When**: Broadcasts depend on state or conditions.

**Pattern**: Guard broadcasts with conditionals.

```ruby
module Card::Broadcastable
  included do
    broadcasts_refreshes unless: :draft?
  end
  
  def broadcast_if_visible
    return if draft? || board.private?
    
    broadcast_replace_later_to([board, :cards])
  end
end
```

**Key Points**:
- Use `unless:` / `if:` options on `broadcasts_refreshes`
- Guard explicit broadcasts with conditionals
- Consider privacy and visibility rules
- Draft/unpublished content shouldn't broadcast

---

## Multi-Tenancy Skills

### SKILL: Account Context in Background Jobs

**When**: Writing jobs that need account context.

**Pattern**: Rely on automatic context preservation; verify in tests.

```ruby
# Context is automatically preserved!
class Card::NotificationJob < ApplicationJob
  def perform(card)
    # Current.account is automatically restored
    card.notify_watchers
  end
end

# Testing account context
class Card::NotificationJobTest < ActiveJob::TestCase
  test "preserves account context" do
    perform_enqueued_jobs do
      assert_equal cards(:david_todo).account, Current.account
      Card::NotificationJob.perform_later(cards(:david_todo))
    end
  end
end
```

**Key Points**:
- `FizzyActiveJobExtensions` automatically handles context
- No manual account passing needed
- Jobs serialize and deserialize `Current.account`
- Test to verify context preservation

---

### SKILL: Cross-Account Operations (Advanced)

**When**: Admin operations or system jobs need to operate across accounts.

**Pattern**: Explicitly manage account context switching.

```ruby
class Admin::AccountsController < AdminController
  def incinerate
    @account = Account.find(params[:id])
    
    # Switch context to target account
    Current.account = @account
    @account.incinerate!
    
    redirect_to admin_accounts_path, notice: "Account incinerated"
  end
end

# System job operating on multiple accounts
class DailyReportJob < ApplicationJob
  def perform
    Account.active.find_each do |account|
      Current.account = account
      generate_report_for(account)
    end
  ensure
    Current.account = nil
  end
end
```

**Key Points**:
- Only for admin or system operations
- Explicitly set `Current.account = account`
- Always clear context in `ensure` block
- Document why cross-account access is needed

---

## Authentication & Authorization Skills

### SKILL: Checking Board Access

**When**: Controllers need to verify user can access a board/card.

**Pattern**: Use `Current.user.can_access?(board)`.

```ruby
class CardsController < ApplicationController
  before_action :set_board
  before_action :authorize_board_access
  
  private
    def set_board
      @board = Current.account.boards.find(params[:board_id])
    end
    
    def authorize_board_access
      head :forbidden unless Current.user.can_access?(@board)
    end
end
```

**Key Points**:
- `can_access?(board)` checks explicit Access records
- All-access boards grant access to all account users
- Check board access, not card access directly
- Return `403 Forbidden` for unauthorized access

---

### SKILL: Role-Based Authorization

**When**: Actions are restricted by user role.

**Pattern**: Check `Current.user.role` or use role predicates.

```ruby
class Account::SettingsController < ApplicationController
  before_action :require_admin
  
  private
    def require_admin
      head :forbidden unless Current.user.admin? || Current.user.owner?
    end
end

# Role predicates
Current.user.owner?   # true if role == "owner"
Current.user.admin?   # true if role == "admin"
Current.user.member?  # true if role == "member"
```

**Roles Hierarchy**:
- `owner` - Full account control, billing, settings
- `admin` - Manage users, boards, most settings
- `member` - Standard user access
- `system` - Internal system user for background operations

---

## Search Skills

### SKILL: Making Models Searchable

**When**: Adding full-text search to a model.

**Pattern**: Include `Searchable` concern and define search content.

```ruby
class Card < ApplicationRecord
  include Searchable
  
  def search_content
    [
      title,
      description&.to_plain_text,
      comments.pluck(:content).join(" ")
    ].compact.join(" ")
  end
end
```

**Key Points**:
- Include `Searchable` concern in model
- Define `search_content` method returning searchable text
- Search records automatically updated after commit
- 16 shards based on account_id hash for performance
- Works with both SQLite (dev) and MySQL (production)

---

### SKILL: Implementing Search Controllers

**When**: Adding search endpoints.

**Pattern**: Query through Search model with account scoping.

```ruby
class SearchesController < ApplicationController
  def show
    @query = params[:q]
    @results = Search.in_account(Current.account)
                    .matching(@query)
                    .limit(50)
  end
end
```

**Key Points**:
- Always scope searches to `Current.account`
- Use `Search.matching(query)` for full-text search
- Limit results for performance
- Search returns polymorphic associations to source records

---

## Migration Skills

### SKILL: Creating Account-Scoped Tables

**When**: Adding new domain models.

**Pattern**: Include account_id, timestamps, and proper indexes.

```ruby
class CreateWidgets < ActiveRecord::Migration[8.0]
  def change
    create_table :widgets, id: :string, limit: 25 do |t|
      t.references :account, null: false, foreign_key: true, type: :string, limit: 25
      t.references :board, null: false, foreign_key: true, type: :string, limit: 25
      
      t.string :name, null: false
      t.text :description
      
      t.timestamps
    end
    
    add_index :widgets, [:account_id, :name], unique: true
    add_index :widgets, [:account_id, :board_id]
  end
end
```

**Key Points**:
- Always include `account_id` reference
- Use `id: :string, limit: 25` for UUID primary keys
- All references are `type: :string, limit: 25`
- Add compound indexes starting with `account_id`
- Include `timestamps` for created_at/updated_at

---

### SKILL: Reversible Migrations

**When**: Complex data migrations.

**Pattern**: Define both up and down directions.

```ruby
class MigrateCardStatuses < ActiveRecord::Migration[8.0]
  def up
    add_column :cards, :status, :string
    
    Card.find_each do |card|
      status = if card.closed_at.present?
        "closed"
      elsif card.column_id.present?
        "active"
      else
        "triage"
      end
      card.update_column(:status, status)
    end
  end
  
  def down
    remove_column :cards, :status
  end
end
```

**Key Points**:
- Use `up`/`down` instead of `change` for complex migrations
- Use `find_each` for batched processing of large tables
- Use `update_column` to bypass callbacks/validations
- Test migrations in both directions
- Consider performance on large datasets

---

## Debugging Skills

### SKILL: Using Rails Console for Investigation

**When**: Debugging issues in development or staging.

**Pattern**: Access models and test logic interactively.

```bash
bin/rails console

# Set account context
Current.account = Account.first

# Test model logic
card = Current.account.cards.first
card.close
card.events.last  # See event created

# Test job logic
Event::RelayJob.perform_now(event)

# Test search
Search.in_account(Current.account).matching("bug")
```

**Key Points**:
- Always set `Current.account` first for proper scoping
- Use `perform_now` to test jobs synchronously
- Use `.reload` to see database changes
- `pp` (pretty print) for readable output

---

### SKILL: Log-Based Debugging

**When**: Investigating production issues or background job failures.

**Pattern**: Use structured logging with context.

```ruby
class ComplexJob < ApplicationJob
  def perform(record)
    Rails.logger.info("Starting complex job", {
      record_id: record.id,
      account_id: record.account_id
    })
    
    process(record)
    
    Rails.logger.info("Completed complex job", {
      record_id: record.id,
      duration: elapsed_time
    })
  rescue => error
    Rails.logger.error("Complex job failed", {
      record_id: record.id,
      error: error.message,
      backtrace: error.backtrace.first(5)
    })
    raise
  end
end
```

**Key Points**:
- Use structured logging with hash of context
- Include record IDs, account IDs for tracing
- Log at start and completion of complex operations
- Rescue and log errors before re-raising
- Keep production logs clean - avoid debug logging

---

### SKILL: Testing Multi-Shard Behavior

**When**: Debugging search or sharded functionality.

**Pattern**: Test with different account IDs to hit different shards.

```ruby
test "search works across shards" do
  # Create accounts that map to different shards
  account1 = Account.create!(name: "Account 1")
  account2 = Account.create!(name: "Account 2")
  
  # Verify different shards
  refute_equal Search.shard_for(account1), Search.shard_for(account2)
  
  # Test search in each shard
  Current.account = account1
  card1 = account1.cards.create!(title: "Test", board: board1)
  assert_includes Search.matching("Test"), card1
  
  Current.account = account2
  card2 = account2.cards.create!(title: "Test", board: board2)
  assert_includes Search.matching("Test"), card2
end
```

**Key Points**:
- Shards determined by CRC32 hash of account_id
- Each account's data isolated to its shard
- Test search behavior in multiple shards
- Verify shard assignment in tests

---

## Additional Skills

### SKILL: Handling Entropy (Auto-Postponement)

**When**: Working with card lifecycle and automatic cleanup.

**Pattern**: Use `Entropic` concern and entropy settings.

```ruby
# Cards automatically postpone after inactivity
module Card::Entropic
  def apply_entropy
    postpone if stale? && board.entropy_enabled?
  end
  
  def stale?
    last_activity_at < entropy_period.ago
  end
  
  def entropy_period
    board.entropy_period || account.entropy_period
  end
end

# Configuration
account.update!(entropy_period: 30.days)
board.update!(entropy_period: 7.days)  # Override for specific board
```

**Key Points**:
- Entropy prevents endless accumulation of stale cards
- Board-level setting overrides account-level default
- `Card::PostponeStaleJob` runs hourly to apply entropy
- Users can manually override by re-activating cards

---

### SKILL: Working with Rich Text (Action Text)

**When**: Handling formatted content with attachments.

**Pattern**: Use Action Text fields and blobs.

```ruby
class Card < ApplicationRecord
  has_rich_text :description
end

# Controller
def card_params
  params.require(:card).permit(:title, :description)  # Rich text handled automatically
end

# View
<%= form.rich_text_area :description %>

# Extracting plain text
card.description.to_plain_text

# Checking for attachments
card.description.embeds.any?
```

**Key Points**:
- Use `has_rich_text :field_name` in model
- Permit field name like any other parameter
- Use `.to_plain_text` for search indexing
- Attachments stored as ActiveStorage blobs
- Automatically handles image uploads, formatting

---

### SKILL: Webhook Integration

**When**: Adding webhook support for events.

**Pattern**: Use Event relaying system.

```ruby
# Webhook model with Event::Relaying
class Event < ApplicationRecord
  include Relaying
  
  def relay_now
    account.webhooks.active.each do |webhook|
      deliver_to_webhook(webhook)
    end
  end
end

# Webhook delivery
webhook.deliveries.create!(
  event: event,
  payload: event.to_webhook_payload,
  delivered_at: Time.current
)

# Testing webhooks
test "event relays to active webhooks" do
  webhook = webhooks(:company)
  
  event = Event.create!(action: :card_created, subject: @card)
  event.relay_now
  
  assert_equal 1, webhook.deliveries.count
end
```

**Key Points**:
- Events automatically enqueue relay jobs after creation
- Only active webhooks receive deliveries
- Deliveries tracked for debugging/monitoring
- Webhook payloads include event details and related objects
- Failed deliveries can be retried

---

## Summary

This SKILLS document provides AI agents with practical, pattern-based guidance for working with the Fizzy codebase. Always:

1. **Follow established patterns** - Look for similar code before creating new patterns
2. **Test thoroughly** - Unit tests for models, system tests for workflows
3. **Respect multi-tenancy** - Always scope through `Current.account`
4. **Use concerns for composition** - Keep models organized with focused concerns
5. **Embrace REST** - Map actions to resources, not custom endpoints
6. **Document conventions** - Add to SKILLS.md when establishing new patterns

For architecture overview, see [AGENTS.md](AGENTS.md).  
For code style rules, see [STYLE.md](STYLE.md).  
For contributing guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).
