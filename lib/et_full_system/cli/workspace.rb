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
  end
end
