require "fileutils"
require "yaml"
require "open3"
require "rake/file_list"
require "forwardable"
require "rspec/support"

module GoldenChild
  class Scenario
    include FileUtils
    extend Forwardable

    attr_reader :name, :command_history, :configuration

    # @!method project_root
    #   (see Configuration#project_root)
    def_delegators :configuration, :golden_path, :actual_root, :project_root,
                   :content_filters

    # @abstract
    Validation = Struct.new(:message)

    class FailedValidation < Validation
      def passed?
        false
      end
    end
    class PassedValidation < Validation
      def passed?
        true
      end
    end

    # @param [String] name The name of the scenario (e.g. RSpec example group)
    def initialize(name:, configuration: ::GoldenChild.configuration)
      @name            = name
      @command_history = []
      @configuration   = configuration
    end

    # Recursively populate the current scenario with copies of files from
    # `source_dir`
    #
    # @param [String, Pathname] source_dir
    # @param [Array] caller
    def populate_from(source_dir, caller=caller)
      Dir.chdir(project_root) do
        raise "Scenario has not been set up" unless actual_path.exist?
        source_dir = Pathname(source_dir)
        unless source_dir.directory?
          fail RuntimeError, "No such directory #{source_dir}", caller
        end

        Dir.foreach(source_dir) do |entry|
          next if %w[. ..].include?(entry)
          copy_entry source_dir + entry, actual_path + entry
        end
      end
    end

    # Run a command in the context of the current scenario.
    #
    # @param [Array] args The command. See {Process.spawn} for the various
    #   forms supported. Note that any environment should be passed via the
    #   `env` option below.
    # @param [true, false] allow_fail (false) Whether to raise an exception
    #   if the command fails.
    # @param [Hash] env Environment variables for the command
    # @param [Array] caller
    # @param [Hash] options
    def run(*args, allow_fail: false, env: self.env, caller: caller, ** options)
      options[:chdir]        ||= actual_path.to_s
      env                    = env.map { |k, v| [k.to_s, v.to_s] }.to_h
      stdout, stderr, status = Open3.capture3(env, *args, ** options)
      command_history.push(
          command: args, status: status, stdout: stdout, stderr: stderr)
      command_log = ""
      command_log << "\nCommand: #{args}"
      command_log << "\nEnvironment:"
      env.each_pair do |key, value|
        command_log << "\n  #{key}=#{value}"
      end
      command_log << "\nExited with status #{status.exitstatus}"
      command_log << "\n========== Command STDOUT ==========\n"
      command_log << stdout
      command_log << "\n========== End STDOUT ==========\n"
      command_log << "\n========== Command STDERR ==========\n"
      command_log << stderr
      command_log << "\n========== End STDERR ==========\n"
      (control_dir + "commands.log").open("a") do |f|
        f.write(command_log)
      end
      unless status.success? || allow_fail
        fail RuntimeError, command_log, caller
      end
    end

    # Unzip a zip file, and execute commands in the context of the unzipped
    # directory.
    #
    # You must have the `unzip(1)` program installed for this to work.helper
    #
    # @param [String, Pathname] relative_filename The path of the zip file
    def within_zip(relative_filename)
      relative_filename = Pathname(relative_filename)
      filename          = actual_path + relative_filename
      raise "Zip file not found: #{filename}" unless filename.exist?
      unzip_dir = unzip_dir_for(relative_filename)
      mkpath unzip_dir
      unzip_succeeded =
          system(*%W[unzip -qq #{filename} -d #{unzip_dir}])
      raise "Could not unzip #{filename}" unless unzip_succeeded
      push_working_dir(unzip_dir.relative_path_from(current_actual_path)) do
        yield(unzip_dir)
      end
    end

    # @return [Pathname]
    def unzip_dir_for(relative_filename)
      current_actual_path + (relative_filename.to_s + ".golden_child_unzip")
    end

    # Verify that `files` are identical to their corresponding gold master
    # files.
    def validate(*files, ** options)
      paths   = Rake::FileList[*files.map(&:to_s)]
      pass    = true
      message = "No files to validate"
      Dir.chdir(project_root) do
        paths.each do |path|
          master_file  = current_master_path + path
          actual_file  = current_actual_path + path
          shortcode    = get_shortcode_for(actual_file)
          approval_cmd = "golden accept #{shortcode}"
          message      = ""
          file_pass    = false
          if !actual_file.exist?
            message << "Expected file: #{actual_file}"
            message << "\nto be created, but it was not."
          elsif !actual_file.file?
            message << "Expected: #{actual_file}"
            message << "\n to be a file, but it is a #{actual_file.ftype}."
          elsif !master_file.exist?
            message << "Master: #{master_file}"
            message << "\ndoes not yet exist."
            message << "\nActual file: #{actual_file}"
            message << "\nhas the following content:\n\n"
            message << filter_file(actual_file)
            message << "\n\nIf this looks correct, run `#{approval_cmd}`"
          elsif !master_file.file?
            message << "Master: #{master_file}"
            message << "must be a file, but it is a #{master_file.ftype}."
          elsif filtered_files_differ?(master_file, actual_file)
            message << "Actual: #{actual_file}"
            message << "\ndiffers from master: #{master_file}"
            message << "\n"
            message << diff(master_file, actual_file)
            message << "\n\nIf the changes look correct, run `#{approval_cmd}`"
          else
            message << "Actual file #{actual_file} matches master #{master_file}"
            file_pass = true
          end
          unless file_pass
            pass = false
            break
          end
        end
      end
      if pass
        PassedValidation.new(message)
      else
        FailedValidation.new(message)
      end
    end

    def filtered_files_differ?(master_file, actual_file)
      filter_file(master_file) != filter_file(actual_file)
    end

    def diff(master_file, actual_file)
      differ      = RSpec::Support::Differ.new
      differences = differ.diff(filter_file(actual_file), filter_file(master_file))
      differences.empty? ? nil : differences
    end

    def filter_file(filename)
      @filtered_files ||= {} # memoization
      @filtered_files.fetch(filename) {
        @filtered_files[filename] = content_filters.reduce(filename.read) {
            |content, filter|
          filter.call(content)
        }
      }
    end

    def get_shortcode_for(actual_file)
      code = state_transaction do |store|
        shortcode_map = (store[:shortcode_map] ||= {})
        shortcode_map.fetch(actual_file.to_s) {
          new_code                        = shortcode_map.values.max.to_i + 1
          shortcode_map[actual_file.to_s] = new_code
        }
      end
      "@#{code}"
    end

    def setup
      mkpath master_path.parent
      rmtree actual_path
      mkpath actual_path
      mkpath control_dir
    end

    def teardown
    end

    def actual_path
      actual_root + relative_path
    end

    alias_method :root, :actual_path

    def master_path
      golden_path + "master" + relative_path
    end

    def current_actual_path
      actual_path + current_working_dir
    end

    def current_master_path
      master_path + current_working_dir
    end

    def control_dir
      actual_path + ".golden_child"
    end

    def relative_path
      slug
    end

    def slug
      name.downcase.tr_s("^a-z0-9", "-")[0..255]
    end

    # @return [Hash] editable env var hash, defaults to {#configuration}
    def env
      @env ||= configuration.env.dup
    end

    private

    def_delegators :configuration, :state_transaction, :get_path_for_shortcode

    def push_working_dir(new_dir)
      dir_stack = working_dir_stack
      dir_stack.push(new_dir)
      yield
    ensure
      dir_stack.pop
    end

    def working_dir_stack
      Thread.current[:golden_child_working_dir] ||= []
    end

    def current_working_dir
      last_dir = working_dir_stack.last
      last_dir || "."
    end
  end
end
