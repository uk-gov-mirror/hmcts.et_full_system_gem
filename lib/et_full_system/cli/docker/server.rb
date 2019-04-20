module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  module Cli
    module Docker
      class ServerCommand < Thor
        desc "up", "Starts the full system server on docker"
        def up
          Bundler.with_original_env do
            gem_root = File.absolute_path('../../../..', __dir__)
            cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml up"
            STDERR.puts cmd
            exec(cmd)
          end
        end

        desc "down", "Stops the full system server on docker"
        def down(*args)
          Bundler.with_original_env do
            gem_root = File.absolute_path('../../../..', __dir__)
            cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml down #{args.join(' ')}"
            STDERR.puts cmd
            exec(cmd)
          end
        end

        default_task :up
      end
    end
  end
end
