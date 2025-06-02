if (Rails.env.production? || Rails.env.beta?) && ENV["SKIP_TELEMETRY"].blank?
  Sentry.init do |config|
    config.dsn = "https://ca338fb1fe6f677d6aeec2336a86f0ee@o33603.ingest.us.sentry.io/4508093839179776"
    config.breadcrumbs_logger = %i[ active_support_logger http_logger ]
    config.send_default_pii = false
    config.release = ENV["GIT_REVISION"]
  end
end
