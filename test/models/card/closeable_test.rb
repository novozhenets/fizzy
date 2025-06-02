require "test_helper"

class Card::CloseableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "closed scope" do
    assert_equal [ cards(:shipping) ], Card.closed
    assert_not_includes Card.open, cards(:shipping)
  end

  test "popping" do
    assert_not cards(:logo).closed?

    cards(:logo).close(user: users(:kevin))

    assert cards(:logo).closed?
    assert_equal users(:kevin), cards(:logo).closed_by
  end

  test "autoclose_at infers the period from the collection" do
    freeze_time

    collections(:writebook).update! auto_close_period: 123.days
    cards(:logo).update! last_active_at: 2.day.ago
    assert_equal (123-2).days.from_now, cards(:logo).auto_close_at
  end
end
