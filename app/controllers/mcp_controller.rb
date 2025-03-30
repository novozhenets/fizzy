class McpController < Rails::ApplicationController
  skip_forgery_protection

  def manifest
    render template: "mcp/manifest", layout: false
  end
end
