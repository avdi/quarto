require 'quarto'
Quarto.configure do |config|
  config.use :git
  config.use :orgmode
  config.use :markdown
  config.use :epubcheck
end
