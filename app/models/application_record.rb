class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }

  connects_to database: { writing: :primary, reading: :replica }
end
