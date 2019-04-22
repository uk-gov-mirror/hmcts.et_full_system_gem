require_relative './docker/server'
module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  class DockerCommand < Thor
    desc "server", "Starts the full system server on docker or can handle other commands too"
    subcommand "server", ::EtFullSystem::Cli::Docker::ServerCommand

    desc "bootstrap", "Used by the docker-compose file (using sudo) - do not use yourself"
    def bootstrap
      Bundler.with_original_env do
        cmd = File.absolute_path('../../../shell_scripts/docker_bootstrap.sh', __dir__)
        puts cmd
        exec(cmd)
      end
    end

    desc "compose", "Provides access to the docker-compose command"
    def compose(*args)
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml #{args.join(' ')}"
        puts cmd
        exec(cmd)
      end
    end
  end
end
