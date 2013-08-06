require 'quarto/plugin'

module Quarto
  class Git < Plugin
    def enhance_build(build)
      build.source_files.exclude(".git/**/*")
      build.source_files.exclude do |file|
        # First check that this is a git repo
        next false unless system("git status -s > /dev/null 2>&1")
        # See if it is a registered file with git
        ls_git = `git ls-files #{file}`
        # See if it is an unregistered but un-ignored file
        ls_other =
          `git ls-files --others --exclude-per-directory .gitignore #{file}`
        # If it shows up in neither of the above, exclude it
        ls_git.empty? && ls_other.empty?
      end
    end
  end
end
