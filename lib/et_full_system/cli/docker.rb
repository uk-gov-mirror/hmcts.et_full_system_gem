require_relative './docker/server'
require 'json'
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

    desc "setup", "Sets up the system for initial run - or after changing branches, adding gems etc.. in any of the services"
    def setup
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "/bin/bash --login -c \"cd /home/app/full_system && et_full_system docker bootstrap && et_full_system local setup\""
        compose_cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml run --rm et #{cmd}"
        puts compose_cmd
        exec(compose_cmd)
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

    desc "reset", "Bring down the server, remove all caches, rebuild the Dockerfile etc..."
    def reset
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml down -v"
        puts cmd
        next unless system(cmd)
        cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml build --no-cache"
        puts cmd
        next unless system(cmd)
        self.class.start(['setup'])
      end
    end

    desc "update_service_url SERVICE URL", "Configures the reverse proxy to connect to a specific url for a service - note the URL must be reachable from the docker container and the server must be running"
    def update_service_url(service, url)
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "/bin/bash --login -c \"et_full_system local update_service_url #{service} #{url}\""
        compose_cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml exec et #{cmd}"
        puts compose_cmd
        exec(compose_cmd)
      end
    end

    desc "local_service SERVICE PORT", "Configures the reverse proxy to connect to a specific port on the host machine - the URL is calculated - otherwise it is the same as update_service_url"
    def local_service(service, port)
      update_service_url(service, local_service_url(port))
    end

    desc "service_env SERVICE", "Returns the environment variables configured for the specified service"
    def service_env(service)
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "/bin/bash --login -c \"et_full_system local service_env #{service}\""
        compose_cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml exec et #{cmd}"
        puts compose_cmd
        exec(compose_cmd)
      end
    end

    private

    def host_ip
      JSON.parse `docker network inspect \`docker network list | grep docker_et_full_system | awk '{print $1}'\``
    end

    def local_service_url(port)
      case ::EtFullSystem.os
      when :linux, :unix
        "http://#{host_ip}:#{port}"
      when :osx
        "http://docker.for.mac.localhost"
      when :windows
        "http://docker.for.windows.localhost"
      else
        raise "Unknown host type - this tool only supports mac, linux and windows"
      end
    end
  end
end
