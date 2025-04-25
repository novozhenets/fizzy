require "test_helper"

class Card::CloseableTest < ActiveSupport::TestCase
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

  test "auto close all due" do
    cards(:logo, :shipping).each(&:reconsider)

    cards(:logo).update!(last_active_at: 1.day.ago - collections(:writebook).auto_close_period)
    cards(:shipping).update!(last_active_at: 1.day.from_now - collections(:writebook).auto_close_period)

    assert_difference -> { Card.closed.count }, +1 do
      Card.auto_close_all_due
    end

    assert cards(:logo).reload.closed?
    assert_not cards(:shipping).reload.closed?
  end

  test "don't auto close those cards where the collection has no auto close period" do
    cards(:logo, :shipping).each(&:reconsider)

    collections(:writebook).update auto_close_period: nil

    assert_no_difference -> { Card.closed.count } do
      Card.auto_close_all_due
    end

    assert_not cards(:logo).reload.closed?
  end
end
