[![PullReview stats](https://www.pullreview.com/github/avdi/quarto/badges/master.svg?)](https://www.pullreview.com/github/avdi/quarto/reviews/master)

# Quarto

Yet another ebook generation toolchain, biased towards writing books about programming.

About the name: "Quarto" is a bookbinding term, and this is my fourth attempt at a reusable ebook toolchain.

## Important Note

Development on Quarto will necessarily occur in fits and starts, because I'll only be working on it actively while I'm writing a book.

It is also very, very unsupported. Right now it exists to solve *my* problems... barely. If it solves your problems too that's fantastic, but I don't have time to help you get it working. Sorry!

## Notable Features

- Accept either Markdown or Org-Mode input files.
- XHTML5 as a universal intermediate format. CSS as a universal styling format. No more maintaining parallel LaTeX or XSL-FO styles for the PDF target.
- SCSS (SASS) support for CSS files.
- PDF output via local PrinceXML **or** DocRaptor.
- Gives DocRaptor a fully standalone source document, with fonts and images embedded using data URIs. There is no need to have the images or fonts be publicly accessible somewhere.
- EPUB3 output via Pandoc.
- EPUB3 font embedding.
- Epubcheck can be incorporated into the production line for automatic validation of generated EPUBs.
- Mobi (Kindle) output via Kindlegen. *Note:* according to the Kindlegen terms of service, the resulting output can only be sold in the Amazon store.
- When producing EPUB, automatically converts unsupported font types to OpenType using FontForge.
- Source code highlighting via Pygments, for maximum breadth of language support.
- Optimized source code highlighting tracks individual listings by SHA1 and only highlights listings that have changed or are new. It also runs multiple highlighting processes in parallel.

## Requirements

Quarto depends on several external programs which you will need to install before using it. Some of these are only required if you use the corresponding plugin.

- Git
- Pandoc
- Pygments
- xmllint
- PrinceXML (the free trial version is fine)
- xmlstarlet
- FontForge

## Getting Started

1. Install the gem (`gem install quarto`)
2. Create a `Rakefile` in your book project root, with the following content:
    
    ```ruby
    require 'quarto/tasks'
    ```
3. Run `rake -T` to see the available tasks.
4. The task you care about is probably `rake deliverables`. (This is    also the default)

## Concepts

Quarto is a set of Rake tasks backed up by a Ruby library, which in turn relies heavily on Nokogiri and a number of external tools.

### Flexibility

Quarto doesn't (yet) introduce any revolutionary ideas to e-publishing. Instead, it ties familiar tools together in a way that lets you write the way you want to. 

There are a lot of tools that try to tie together an end-to-end publishing pipeline. But when you want to interpose your own processing in between steps, you're out of luck. The fact that Quarto is structured as a set of Rake tasks means that you can add your own dependencies, your own steps, or tack extra processing onto any of the existing steps just by adding to your project's `Rakefile`.

### Explorability

There is a well-defined set of steps with documented inputs and output artifacts (see below). These artifacts of the build process are left behind in a `build` directory in your project root, so it's easy to understand what Quarto is doing at each step of the way. There's nothing hidden in anonymous temporary files.

### The best tools for the job

Quarto tries to pick the best tools for each step in the book-building chain. So for instance, while some Markdown parsers support limited syntax highlighting of source code, Quarto instead uses Pygments to highlight code listings as a separate (and highly optimized) step. This ensures that high-quality highlighting is available for the widest possible variety of source code languages.

### Prefer the command line

When there is an option to either perform an operation in pure Ruby and shell out to a command-line tool without too much added pain, Quarto prefers to shell out to the tool. This may seem counterintuitive, since it means more dependencies. The advantage is that since Rake echoes shell commands to the console, you can *see* exactly what Quarto is doing. You can even copy and paste the commands to try them yourself.

In the future, I hope to make it so that even tasks that are implemented in pure Ruby can be easily invoked independently from the command line. The goal is to have the output of a Quarto run be a series of commands that you could run manually and get the same results.

### XHTML5 is king

A central philosophy of Quarto is to do as much work as possible with XHTML5 files. All input formats (e.g. Markdown) are first converted to XHTML5 before any other work is done. Then various transformations occur. Finally, at the end of the line, an XHTML5 "master" file is converted to various deliverable formats such as PDF. The reason for this philosophy is simple: Nokogiri makes it really easy to perform arbitrary semantic transformations on XHTML documents, without a lot of tedious mucking about with text munging. The more of the work that is done on DOM object trees, the easier it is to do.

XHTML5 is also sufficiently rich and expressive that most formats can be converted to it without losing information.  And XHTML5 is at the heart of both EPUB3 and Kindle Format 8, the leading ebook publishing formats.

### The assembly line

Quarto is a set of Rake tasks, so execution normally starts with a desired end product and works backwards through the dependency chain to figure out what needs to be done to produce that product. However, it's probably easier to understand everything Quarto does by viewing it as an assembly line starting with source files and ending with deliverables. Here are the steps along the way.

Note that all files generated by Quarto are placed in a `build` subdirectory of your project's root. It will be created if needed.

1. **Source files**. These are manuscript files in supported source    formats (currently Markdown and Org-Mode). They might be in the root of your project, or in subdirectories.
2. Source files are *exported* into **export files** in `build/export`. Export files are HTML, produced using whatever tool is appropriate for the input format. E.g. `pandoc` is used to export Markdown source files to HTML equivalents.
3. The source files are then normalized into XHTML **signature files** (in `build/signatures`). During this normalization process any idiosyncrasies in the HTML produced by the export tool are dealt with.
4. A **spine file** is generated. This XHTML file will be used to tie together all of the section files. The body of this file contains references to (but not the content of) all of the signature files. It also contains stylesheets and other metadata.
5. The spine file is then expanded into an XHTML **codex file**. This file contains the body content of all of the signature files concatenated together. Only body content is taken from the signature files, everything else is ignored. From this point forward, all operations will be done on monolithic files rather than on partial files corresponding to the original sources.
6. The codex file is searched for source code listings. Each listing is extracted out as text into a **listing file** (in `build/listings`). Listing files are named based on the SHA1 of the listing and its language, e.g. `build/listings/3361c5f02e08bd44bde2d42633a2c9be201f7ec4.rb`. Using the SHA1 in naming is an optimization which ensures that only changed code listings ever need to be re-highlighted (see the next step). During this step a **skeleton file** is also created. This XHTML file mirrors the codex file, except that all of the source code listings have been replaced with references to highlight files (see next step).
7. The next step is to perform source code highlighting on the listing files, using Pygments. This produces **highlight files**, which are HTML files in the `build/highlights` directory. They named based on the SHA1 of the corresponding code listing.
8. The skeleton file and the highlights file are then stitched back together into a **master file**. This XHTML file is the "gold standard" from which all deliverables will be generated.
9. Some end products, such as a generated web site, may need the book to be re-broken into individual files. Toward this end, the master file is split into **fascicle files**. ("Fascicle" is a term for an individual part of a book that has been printed as a serial.) A fascicle contains the body of one of the original section files, but with all the styling, metadata, source highlighting, etc. of a master file. A fascicle is a good candidate for generating standalone "sample chapters".
10. **Deliverable files** suitable for distributing to end-users, such as PDF or Epub files, are produced using the master file. The plugins that handle production of deliverables may create various other intermediate files during this process.

## Detailed Usage

### Configuration

Quarto can be configured by requiring `quarto` instead of `quarto/tasks`, and calling `Quarto.configure`. Here is the configuration for my book "Confident Ruby":

```ruby
require 'quarto'

Quarto.configure do |config|
  config.author              = "Avdi Grimm"
  config.title               = "Confident Ruby"

  config.use :git
  config.use :orgmode       # if you want to use org-mode
  config.use :markdown      # if you want to use markdown
  config.use :doc_raptor
  config.use :pandoc_epub
  config.use :epubcheck
  config.use :kindlegen
  config.use :bundle
  config.source_files                    = ["confident-ruby.org"]
  config.bitmap_cover_image              = "images/cover-large.png"
  config.vector_cover_image              = "images/cover.svg"
  config.stylesheets.cover_color         = "#fff4cd"
  config.stylesheets.heading_font        = '"PT Sans", sans-serif'
  config.stylesheets.font                = '"PT Serif", serif'
  config.add_font("PT Sans", file: "fonts/PT_Sans-Web-Regular.ttf")
  config.add_font(
    "PT Sans",
    weight: "bold",
    file: "fonts/PT_Sans-Web-Bold.ttf")
  config.add_font(
    "PT Sans",
    style:  "italic",
    file: "fonts/PT_Sans-Web-Italic.ttf")
  config.add_font(
    "PT Sans",
    weight: "bold",
    style:  "italic",
    file: "fonts/PT_Sans-Web-BoldItalic.ttf")
  config.add_font("PT Serif", file: "fonts/PT_Serif-Web-Regular.ttf")
  config.add_font(
    "PT Serif",
    weight: "bold",
    file: "fonts/PT_Serif-Web-Bold.ttf")
  config.add_font(
    "PT Serif",
    style:  "italic",
    file: "fonts/PT_Serif-Web-Italic.ttf")
  config.add_font(
    "PT Serif",
    weight: "bold",
    style:  "italic",
    file: "fonts/PT_Serif-Web-BoldItalic.ttf")
  config.add_font("Source Code Pro", file: "fonts/SourceCodePro-Regular.otf")
  config.add_font(
    "Source Code Pro",
    weight: "bold",
    file: "fonts/SourceCodePro-Bold.otf")
end
```

### Explicitly setting source files

By default Quarto seeks out source files with extensions it knows about. Alternatively, you can explicitly define the list of source files to use, and the order in which to use them.

```ruby
Quarto.configure do |config|
  config.source_files << [
    "ch1.md",
    "subdir/ch3.org"
  ]
end
```

### Excluding files

By default Quarto looks for any source files with extensions it knows (such as `.md`) and includes them in the build. There are some exceptions to this however, and some ways to influence which source files it considers for inclusion.

First of all, the `build` directory will always be excluded from the search. So will any `.git` directory.

If the project is under Git control and you use the `:git` plugin, any files ignored by Git (via `.gitignore`) will be ignored by Quarto.

Finally, you can add exclusion patterns in the Quarto configuration.

```ruby
Quarto.configure do |config|
  config.exclude_source("~*")
end
```

Exclusion patterns can be shell glob strings or regular expressions (anything supported by Rake [`FileList#exclude`](http://rake.rubyforge.org/Rake/FileList.html#method-i-exclude)).

### Enabling optional functionality

```ruby
Quarto.configure do |config|
  config.use :orgmode
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
