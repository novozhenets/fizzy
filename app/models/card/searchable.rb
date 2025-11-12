module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    scope :mentioning, ->(query, user:) do
      query = Search::Query.wrap(query)

      if query.valid?
        table_name = Searchable.search_index_table_name(user.account_id)
        uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)
        serialized_board_ids = user.board_ids.map { |id| uuid_type.serialize(id) }

        joins("INNER JOIN #{table_name} ON #{table_name}.card_id = cards.id AND #{table_name}.board_id = cards.board_id")
          .where("#{table_name}.board_id IN (?)", serialized_board_ids)
          .where("MATCH(#{table_name}.content, #{table_name}.title) AGAINST(? IN BOOLEAN MODE)", query.to_s)
          .distinct
      else
        none
      end
    end
  end

  private
    def search_title
      Search::Stemmer.stem title
    end

    def search_content
      Search::Stemmer.stem description.to_plain_text
    end

    def search_card_id
      id
    end

    def search_board_id
      board_id
    end
end
