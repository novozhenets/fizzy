require "test_helper"

class Card::EntropyTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
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

  test "auto_reconsider_all_stagnated" do
    travel_to Time.current

    cards(:logo, :shipping).each(&:engage)

    cards(:logo).update!(last_active_at: 1.day.ago - Card::AUTO_RECONSIDER_PERIOD)
    cards(:shipping).update!(last_active_at: 1.day.from_now - Card::AUTO_RECONSIDER_PERIOD)

    assert_difference -> { Card.considering.count }, +1 do
      Card.auto_reconsider_all_stagnated
    end

    assert cards(:shipping).reload.doing?
    assert cards(:logo).reload.considering?
    assert_equal Time.current, cards(:logo).last_active_at
  end
end
