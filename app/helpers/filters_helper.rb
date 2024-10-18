module FiltersHelper
  def main_filter_text
    (Bucket::View::ORDERS[params[:order_by]] || Bucket::View::STATUSES[params[:status]] || Bubble.default_order_by).humanize
  end

  def tag_filter_text
    if @tag_filters
      @tag_filters.map(&:hashtag).to_choice_sentence
    else
      "any tag"
    end
  end

  def assignee_filter_text
    if @assignee_filters
      "assigned to #{@assignee_filters.map(&:name).to_choice_sentence}"
    else
      "assigned to anyone"
    end
  end

  # `#bubble_filter_params` is memoized to avoid spam in logs about unpermitted params
  def bubble_filter_params
    @bubble_filter_params ||= params.permit :order_by, :status, assignee_ids: [], tag_ids: []
  end

  def view_filter_params
    bubble_filter_params.merge params.permit :term, :view_id
  end

  def querying_unassigned_status?
    params[:status] == "unassigned"
  end
end
