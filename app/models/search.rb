class Search
  attr_reader :user, :query

  def self.table_name_prefix
    "search_"
  end

  def initialize(user, query)
    @user = user
    @query = Query.wrap(query)
  end

  def results
    if query.valid? && board_ids.any?
      perform_search
    else
      Search::Result.none
    end
  end

  private
    def board_ids
      @board_ids ||= user.board_ids
    end

    def perform_search
      query_string = query.to_s
      sanitized_raw_query = Search::Result.connection.quote(query.terms)
      table_name = Searchable.search_index_table_name(user.account_id)
      uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)
      serialized_board_ids = board_ids.map { |id| uuid_type.serialize(id) }

      Search::Result.from(table_name)
        .joins("INNER JOIN cards ON #{table_name}.card_id = cards.id")
        .joins("INNER JOIN boards ON cards.board_id = boards.id")
        .where("#{table_name}.board_id IN (?)", serialized_board_ids)
        .where("MATCH(#{table_name}.content, #{table_name}.title) AGAINST(? IN BOOLEAN MODE)", query_string)
        .select([
          "#{table_name}.card_id as card_id",
          "CASE WHEN #{table_name}.searchable_type = 'Comment' THEN #{table_name}.searchable_id ELSE NULL END as comment_id",
          "boards.name as board_name",
          "cards.creator_id",
          "#{table_name}.created_at as created_at",
          "#{sanitized_raw_query} AS query"
        ].join(","))
        .order("#{table_name}.created_at DESC")
    end
end
