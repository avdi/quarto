require "quarto/path_helpers"
require "rake"

module Quarto
  class Template
    include Comparable
    include PathHelpers
    attr_reader :logical_path, :layout, :template_set

    def initialize(logical_path, template_set, layout: nil)
      @logical_path = logical_path
      @template_set = template_set
      @layout       = layout
    end

    def <=>(other)
      logical_path <=> other.logical_path
    end

    def partial?
      !!(logical_path.pathmap("%f")[0] =~ /^_/)
    end

    def complete?
      !partial?
    end

    def html?
      target_extension == "html"
    end

    def available_from_system?
      !!concrete_system_path
    end

    def target_extension
      logical_path.pathmap("%x")[1..-1].downcase
    end

    def target_path
      "#{build_dir}/#{logical_path}"
    end

    def exists?
      !!concrete_path
    end

    def concrete_path
      concrete_user_path || concrete_system_path
    end

    def concrete_user_path
      template_for(logical_path, user_template_dir)
    end

    def concrete_system_path
      template_for(logical_path, system_template_dir)
    end

    def template_for(base_path, root)
      FileList["#{root}/#{base_path}",
        "#{root}/#{base_path}.*"].existing.first
    end

    def metamorphoses(path=concrete_path)
      dir, logical_dir, basename = path_parts(path)
      if path == target_path
        [path]
      elsif basename == logical_basename
        [path] + metamorphoses(target_path)
      elsif (basename = pop_ext(basename)) == logical_basename
        [path] + metamorphoses(target_path)
      else
        next_path = clean_path("#{logical_expansion_dir}/#{basename}")
        [path] + metamorphoses(next_path)
      end
    end

    def pop_ext(path)
      path, dot, ext = path.rpartition(".")
      path
    end

    def path_parts(path=concrete_path)
      dir  = path.pathmap("%d")
      base = path.pathmap("%f")
      dir_pattern = /
          \A(
            #{system_template_dir} |
            #{user_template_dir} |
            #{expansion_dir} |
            #{build_dir}
           )
           (\/(.*))?\z/x
      md = dir_pattern.match(dir)
      base_dir, logical_dir = md[1], md[3] || "."
      [base_dir, logical_dir, base]
    end

    def logical_expansion_dir
      clean_path("#{expansion_dir}/#{logical_dir}")
    end

    def expansion_dir
      template_set.template_expansion_dir
    end

    def logical_dir
      logical_path.pathmap("%d")
    end

    def logical_basename
      logical_path.pathmap("%f")
    end

    def system_template_dir
      template_set.system_template_dir
    end

    def user_template_dir
      template_set.user_template_dir
    end

    def build_dir
      template_set.build_dir
    end
  end
end
