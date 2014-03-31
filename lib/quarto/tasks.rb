require 'quarto'
Quarto.configure do |config|
  config.use :orgmode
  config.use :markdown
  config.use :pandoc_epub
  config.use :epubcheck
end
