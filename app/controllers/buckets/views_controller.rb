class Buckets::ViewsController < ApplicationController
  include BucketScoped

  before_action :set_view, only: %i[ update destroy ]

  def create
    @view = @bucket.views.create! filters: filter_params
    redirect_to bucket_bubbles_path(@bucket, **filter_params.merge(view_id: @view.id)), notice: "✓"
  end

  def update
    @view.update! filters: filter_params
    redirect_to bucket_bubbles_path(@bucket, **filter_params.merge(view_id: @view.id)), notice: "✓"
  end

  def destroy
    @view.destroy
    redirect_to bucket_bubbles_path(@bucket, **filter_params), notice: "✓"
  end

  private
    def set_view
      @view = @bucket.views.find params[:id]
    end

    def filter_params
      helpers.bubble_filter_params.to_h.compact_blank
    end
end
