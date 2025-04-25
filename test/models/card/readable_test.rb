require "test_helper"

class Card::ReadableTest < ActiveSupport::TestCase
  test "read clears events notifications" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
        cards(:logo).read_by(users(:kevin))
      end
    end
  end

  test "read clear mentions in the description" do
    assert_changes -> { notifications(:logo_card_david_mention_by_jz).reload.read? }, from: false, to: true do
      cards(:logo).read_by(users(:david))
    end
  end

  test "read clear mentions in comments" do
    assert_changes -> { notifications(:logo_comment_david_mention_by_jz).reload.read? }, from: false, to: true do
      cards(:logo).read_by(users(:david))
    end
  end

  test "read clears notifications from the comments" do
    assert_changes -> { notifications(:layout_commented_kevin).reload.read? }, from: false, to: true do
      cards(:layout).read_by(users(:kevin))
    end
  end
end
