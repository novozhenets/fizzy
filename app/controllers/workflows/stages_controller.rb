class Workflows::StagesController < ApplicationController
  include WorkflowScoped

  before_action :set_stage, only: %i[ edit update destroy ]

  def new
    @stage = @workflow.stages.new
  end

  def create
    @stage = @workflow.stages.create! stage_params
    redirect_to workflow_path(@workflow)
  end

  def edit
  end

  def update
    @stage.update! stage_params
    redirect_to workflow_path(@workflow)
  end

  def destroy
    @stage.destroy
    redirect_to workflow_path(@workflow)
  end

  private
    def set_stage
      @stage = @workflow.stages.find params[:id]
    end

    def stage_params
      params.expect(workflow_stage: [ :name ])
    end
end
