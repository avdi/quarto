module Quarto
  class Epubcheck < Plugin
    fattr(:version) { "3.0.1" }

    def define_tasks

      task :deliverables => :epubcheck

      namespace :epubcheck do
        desc "Download and prepare epubcheck"
        task :vendor => epubcheck_jar
      end

      desc "Validate EPUB file(s) with epubcheck"
      task :epubcheck => [epubcheck_jar, :epub] do |t|
        files = FileList["#{main.deliverable_dir}/*.epub"]
        files.each do |epub_file|
          sh(*%W[java -jar #{epubcheck_jar} #{epub_file} -v 3.0]) do
            # Ignore errors for now
          end
        end
      end

      file epubcheck_jar => epubcheck_package do |t|
        cd main.vendor_dir do
          sh *%W[unzip #{package_name}]
        end
      end

      file epubcheck_package do |t|
        cd t.name.pathmap("%d") do
          sh *%W[wget #{package_url}]
        end
      end
    end

    private

    def epubcheck_jar
      "#{main.vendor_dir}/epubcheck-#{version}/epubcheck-#{version}.jar"
    end

    def epubcheck_package
      "#{main.vendor_dir}/#{package_name}"
    end

    def package_name
      "epubcheck-#{version}.zip"
    end

    def package_url
      "https://epubcheck.googlecode.com/files/epubcheck-#{version}.zip"
    end
  end
end
