require "test_helper"

class Cards::DropsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "drop to considering" do
    assert_changes -> { @card.reload.considering? }, from: false, to: true do
      post cards_drops_path, params: { dropped_item_id: @card.id, drop_target: "considering" }, as: :turbo_stream
      assert_column_rerendered("considering")
    end
  end

  test "drop to doing" do
    @card = cards(:text)

    assert_changes -> { @card.reload.doing? }, from: false, to: true do
      post cards_drops_path, params: { dropped_item_id: @card.id, drop_target: "doing" }, as: :turbo_stream
      assert_column_rerendered("doing")
    end
  end

  test "invalid drop target" do
    post cards_drops_path, params: { dropped_item_id: @card.id, drop_target: "invalid" }, as: :turbo_stream
    assert_response :bad_request
  end

  private
    def assert_column_rerendered(target)
      assert_turbo_stream action: :replace, target: "#{target}-cards"
    end
end
