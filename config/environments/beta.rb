require_relative "production"

Rails.application.configure do
  config.action_mailer.default_url_options = { host: "%{tenant}.37signals.works" }

  # Let's keep beta on local disk. See https://github.com/basecamp/fizzy/pull/557 for context.
  config.active_storage.service = :local
end
