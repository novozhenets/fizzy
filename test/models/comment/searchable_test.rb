require "test_helper"

class Comment::SearchableTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    16.times { |i| ActiveRecord::Base.connection.execute "DELETE FROM search_index_#{i}" }
    Account.find_by(name: "Search Test")&.destroy

    @account = Account.create!(name: "Search Test")
    @user = User.create!(name: "Test User", account: @account)
    @board = Board.create!(name: "Test Board", account: @account, creator: @user)
    @card = @board.cards.create!(title: "Test Card", creator: @user)
    Current.account = @account
  end

  teardown do
    16.times { |i| ActiveRecord::Base.connection.execute "DELETE FROM search_index_#{i}" }
    Account.find_by(name: "Search Test")&.destroy
  end

  test "comment search" do
    table_name = Searchable.search_index_table_name(@account.id)
    uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)

    # Comment is indexed on create
    comment = @card.comments.create!(body: "searchable comment text", creator: @user)
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([
        "SELECT COUNT(*) FROM #{table_name} WHERE searchable_type = 'Comment' AND searchable_id = ?",
        uuid_type.serialize(comment.id)
      ])
    ).first[0]
    assert_equal 1, result

    # Comment is updated in index
    comment.update!(body: "updated text")
    content = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([
        "SELECT content FROM #{table_name} WHERE searchable_type = 'Comment' AND searchable_id = ?",
        uuid_type.serialize(comment.id)
      ])
    ).first[0]
    assert_match /updat/, content

    # Comment is removed from index on destroy
    comment_id = comment.id
    comment.destroy
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([
        "SELECT COUNT(*) FROM #{table_name} WHERE searchable_type = 'Comment' AND searchable_id = ?",
        uuid_type.serialize(comment_id)
      ])
    ).first[0]
    assert_equal 0, result

    # Finding cards via comment search
    card_with_comment = @board.cards.create!(title: "Card One", creator: @user)
    card_with_comment.comments.create!(body: "unique searchable phrase", creator: @user)
    card_without_comment = @board.cards.create!(title: "Card Two", creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_with_comment
    assert_not_includes results, card_without_comment

    # Comment stores parent card_id and board_id
    new_comment = @card.comments.create!(body: "test comment", creator: @user)
    row = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([
        "SELECT card_id, board_id FROM #{table_name} WHERE searchable_type = 'Comment' AND searchable_id = ?",
        uuid_type.serialize(new_comment.id)
      ])
    ).first
    # Deserialize binary UUIDs from result
    assert_equal @card.id, uuid_type.deserialize(row[0])
    assert_equal @board.id, uuid_type.deserialize(row[1])
  end
end
