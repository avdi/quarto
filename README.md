# Quarto

Yet another ebook generation toolchain.

A "Quarto" is a bookbinding term, and this is my fourth attempt at an ebook toolchain.

## Requirements

Quarto depends on several external programs which you will need to install before using it.

- Pandoc
- Pygments
- xmllint

## Installation/Usage

1. Install the gem (`gem install quarto`)
2. Create a `Rakefile` in your book project root.
3. Add `require "quarto/tasks"` to the top of the Rakefile.
4. Run `rake -T` to see the available tasks.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
