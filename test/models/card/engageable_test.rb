require "test_helper"

class Card::EngageableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "check the engagement status of a card" do
    assert cards(:logo).doing?
    assert_not cards(:text).doing?

    assert_not cards(:logo).considering?
    assert cards(:text).considering?

    assert_equal "doing", cards(:logo).engagement_status
    assert_equal "considering", cards(:text).engagement_status
  end

  test "change the engagement" do
    assert_changes -> { cards(:text).reload.doing? }, to: true do
      cards(:text).engage
    end

    assert_changes -> { cards(:logo).reload.doing? }, to: false do
      cards(:logo).reconsider
    end
  end

  test "engaging with closed cards" do
    cards(:text).close

    assert_not cards(:text).considering?
    assert_not cards(:text).doing?

    cards(:text).engage
    assert_not cards(:text).reload.closed?
    assert cards(:text).doing?

    cards(:text).close
    cards(:text).reconsider
    assert_not cards(:text).reload.closed?
    assert cards(:text).considering?
  end

  test "scopes" do
    assert_includes Card.doing, cards(:logo)
    assert_not_includes Card.doing, cards(:text)

    assert_includes Card.considering, cards(:text)
    assert_not_includes Card.considering, cards(:logo)
  end
end
