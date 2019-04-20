module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  class DockerCommand < Thor
    desc "server", "Starts the full system server on docker"
    def server
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml up"
        STDERR.puts cmd
        exec(cmd)
      end
    end

  end
end
