require 'quarto'
Quarto.configure do |config|
  config.use :git
  config.use :orgmode
  config.use :markdown
  config.use :pandoc_epub
  config.use :epubcheck
end
