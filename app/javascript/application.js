// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "initializers"
import "controllers"

import "actiontext-lexical"
import "@rails/actiontext"

window.fetch = Turbo.fetch // TODO: We need to make @rails/request.js use Turbo's fetch when it's present.
