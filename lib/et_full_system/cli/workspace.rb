module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  require "rubygems"
  require "thor"

  class WorkspaceCommand < Thor

    desc "new", "Creates a new workspace in the current directory.  The directory must be empty"
    def new
      return unless yes?("Are you sure that you want to clone all system repositories for employment tribunals into this directory ?")
      return say "The current directory must be empty" unless Dir.empty?(Dir.pwd)
      puts `git clone --recursive git@github.com:hmcts/et-full-system-servers.git .`
    end

    desc "pull", "Pulls the latest version from the repository and updates the submodules"
    def pull
      return say "Please change to a workspace setup by this tool" unless File.exist?(File.join(Dir.pwd, 'et-full-system.dir'))
      puts `git pull && git submodule update`
    end

    desc "checkout <branch-or-commit>", "Checkout a branch or a specific commit, then updates the submodules"
    def checkout(branch_or_commit)
      return say "Please change to a workspace setup by this tool" unless File.exist?(File.join(Dir.pwd, 'et-full-system.dir'))
      puts `git checkout #{branch_or_commit}`
      puts `git submodule update`
    end
  end
end
