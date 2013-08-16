module Quarto
  class PandocEpub < Plugin
    module BuildExt
      extend Forwardable

      attr_accessor :pandoc_epub
    end

    fattr(:flags) { %W[-w epub3] }

    def enhance_build(build)
      build.extend(BuildExt)
      build.pandoc_epub = self
    end

    def define_tasks
      desc "Build an epub file with pandoc"
      task :epub => :"pandoc_epub:epub"

      namespace :pandoc_epub do
        task :epub => epub_file
      end

      file epub_file => :master do |t|
        create_epub_file(t.name, main.master_file)
      end
    end

    private

    def create_epub_file(epub_file, master_file)
      master_dir = master_file.pathmap("%d")
      epub_file = Pathname(epub_file)
        .relative_path_from(Pathname(master_dir))
        .to_s
      cd master_dir do
        sh "pandoc", "-o", epub_file, master_file.pathmap("%f"), *flags
      end
    end

    def epub_file
      "#{main.deliverable_dir}/book.epub"
    end
  end
end
