class WorkflowsController < ApplicationController
  before_action :set_workflow, only: %i[ show edit update destroy ]

  def index
    @workflows = Current.account.workflows
  end

  def new
    @workflow = Current.account.workflows.new
  end

  def create
    @workflow = Current.account.workflows.create! workflow_params
    # FIXME: this should definitely change.
    %w[ Triage WIP On-hold ].each { |name| @workflow.stages.create! name: name }
    redirect_to workflows_path
  end

  def show
  end

  def edit
  end

  def update
    @workflow.update! workflow_params
    redirect_to workflow_path(@workflow)
  end

  def destroy
    @workflow.destroy
    redirect_to workflows_path
  end

  private
    def set_workflow
      @workflow = Current.account.workflows.find params[:id]
    end

    def workflow_params
      params.expect(workflow: [ :name ])
    end
end
