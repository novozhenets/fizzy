module FilterScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_filter
  end

  private
    DEFAULT_PARAMS = { indexed_by: "latest" }

    def set_filter
      @filter = Current.user.filters.from_params params.reverse_merge(**DEFAULT_PARAMS).permit(*Filter::PERMITTED_PARAMS)
    end
end
