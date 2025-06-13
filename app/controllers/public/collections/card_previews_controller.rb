class Public::Collections::CardPreviewsController < ApplicationController
  include PublicCollectionScoped

  allow_unauthenticated_access only: :index

  def index
    set_page_and_extract_portion_from find_cards, per_page: CardsController::PAGE_SIZE
  end

  private
    def find_cards
      case params[:target]
      when "considering-cards"
        @collection.cards.considering.latest
      when "doing-cards"
        @collection.cards.doing.latest
      when "closed-cards"
        @collection.cards.closed.recently_closed_first
      else
        raise ActionController::BadRequest
      end
    end
end
