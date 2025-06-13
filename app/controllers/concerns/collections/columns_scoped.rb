module Collections::ColumnsScoped
  extend ActiveSupport::Concern

  included do
    include FilterScoped
  end

  def page_and_filter_for(filter, per_page: nil)
    cards = block_given? ? yield(filter.cards) : filter.cards

    OpenStruct.new \
      page: GearedPagination::Recordset.new(cards, per_page:).page(1),
      filter: filter
  end

  def page_and_filter_for_closed_cards
    if @filter.indexed_by.stalled?
      page_and_filter_for(@filter, per_page: CardsController::PAGE_SIZE) { |cards| cards.recently_closed_first }
    else
      page_and_filter_for(@filter.with(indexed_by: "closed"), per_page: CardsController::PAGE_SIZE) { |cards| cards.recently_closed_first }
    end
  end
end
