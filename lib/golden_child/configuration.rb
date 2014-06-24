require "golden_child/block_content_filter"

module GoldenChild
  class Configuration
    # @return [Pathname] the directory in which "actual" results will be generated
    def actual_root
      golden_path + "actual"
    end

    # @return [Pathname] the base directory for gold master dirs
    def master_root
      golden_path + "master"
    end

    # @return [Pathname] the root directory for everything GoldenChild does
    def golden_path
      Pathname("spec/golden")
    end

    # @return [Pathname] the root directory of the current project
    def project_root
      @project_root ||= Pathname.pwd
    end

    # @param [String, Pathname] new_root set the project root directory
    def project_root=(new_root)
      @project_root = Pathname(new_root).expand_path
    end

    # @return [Hash] The global, editable set of default env vars
    def env
      @env ||= {}
    end

    # @return [Enumerable<BlockContentFilter>] the configured
    #   content filters
    def content_filters
      @content_filters ||= []
    end

    # Add a filter for a given file pattern. Filters are useful for removing
    # volatile information (like timestamps) from the files to be compared.
    # **NOTE:** filters are currently **not** suitable for removing sensitive
    # information, since they are only applied when diffing files. The files
    # on disk are not filtered.
    #
    # @param [Array<String, [#===]>] patterns Filename patterns that
    #   determine which files this filter should be applied to. Strings are
    #   treated as file glob patterns.
    # @yieldparam [String] file_content the contents of the file
    # @yieldreturn [String] the filtered file contents
    def add_content_filter(*patterns, &filter)
      content_filters << BlockContentFilter.new(patterns, filter)
    end

    # @param [String] code
    # @return [String] path to the corresponding file
    # @raise [UserError] if the shortcode is not found
    #
    # TODO: Move this out of Configuration
    def get_path_for_shortcode(code)
      value = code[/\d+/].to_i
      state_transaction(read_only: true) do |store|
        store[:shortcode_map].invert.fetch(value) do
          fail UserError, "Shortcode not found: #{code}"
        end
      end
    end

    # @yield [YAML::Store]
    #
    # TODO: Move this out of Configuration
    def state_transaction(read_only: false)
      config_dir = project_root + ".golden_child"
      mkpath config_dir unless config_dir.exist?
      state_db = config_dir + "state.yaml"
      store    = YAML::Store.new(state_db)
      store.transaction(read_only) do
        yield store
      end
    end

  end
end
