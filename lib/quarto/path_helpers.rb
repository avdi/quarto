module Quarto
  module PathHelpers
    module_function

    def rel_path(file, dir)
      Pathname(file).relative_path_from(Pathname(dir)).to_s
    end
  end
end
