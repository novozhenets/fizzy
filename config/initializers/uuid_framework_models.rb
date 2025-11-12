# Inject UUID primary key support into Rails framework models
Rails.application.config.to_prepare do
  ActionText::RichText.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
  ActiveStorage::Attachment.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
  ActiveStorage::Blob.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
  ActiveStorage::VariantRecord.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
end
