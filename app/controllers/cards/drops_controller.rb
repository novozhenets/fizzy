class Cards::DropsController < ApplicationController
  include Collections::ColumnsScoped
  before_action :set_card, :set_drop_target

  def create
    perform_drop_action
    render_column_replacement
  end

  private
    VALID_DROP_TARGETS = %w[ considering doing ]

    def set_card
      @card = Current.user.accessible_cards.find(params[:dropped_item_id])
    end

    def set_drop_target
      if params[:drop_target].in?(VALID_DROP_TARGETS)
        @drop_target = params[:drop_target].to_sym
      else
        head :bad_request
      end
    end

    def perform_drop_action
      case @drop_target
      when :considering
          @card.reconsider
      when :doing
          @card.engage
      end
    end

    def render_column_replacement
      page_and_filter = page_and_filter_for @filter.with(engagement_status: @drop_target.to_s), per_page: CardsController::PAGE_SIZE
      render turbo_stream: turbo_stream.replace("#{@drop_target}-cards", method: :morph, partial: "cards/index/engagement/#{@drop_target}", locals: page_and_filter.to_h)
    end
end
