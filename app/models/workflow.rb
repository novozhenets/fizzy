class Workflow < ApplicationRecord
  DEFAULT_STAGES = [
    { name: "Figuring it out", color: "var(--color-card-5)" },
    { name: "In progress", color: "var(--color-card-3)" }
  ]

  has_many :stages, dependent: :delete_all

  after_create_commit :create_default_stages

  private
    def create_default_stages
      Workflow::Stage.insert_all(DEFAULT_STAGES.map { { name: it[:name], color: it[:color], workflow_id: id } })
    end
end
