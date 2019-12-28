require_relative './docker/server'
require_relative '../os'
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
        compose_cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml run --rm et #{cmd}"
        puts compose_cmd
        exec(compose_cmd)
      end
    end

    desc "compose", "Provides access to the docker-compose command"
    def compose(*args)
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml #{args.join(' ')}"
        puts cmd
        exec(cmd)
      end
    end

    desc "invoker", "Provides access to the invoker system running inside docker"
    def invoker(*args, show_output: true, show_command: true)
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml exec et bash -lc \"invoker #{args.join(' ')}\""
        puts cmd if show_command
        result = `#{cmd}`
        puts result if show_output
      end
    end

    desc "reset", "Bring down the server, remove all caches, rebuild the Dockerfile etc..."
    def reset
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml down -v"
        puts cmd
        next unless system(cmd)
        cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml build --no-cache"
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
        compose_cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml exec et #{cmd}"
        puts compose_cmd
        `#{compose_cmd}`
      end
    end

    desc "local_service SERVICE PORT", "Configures the reverse proxy to connect to a specific port on the host machine - the URL is calculated - otherwise it is the same as update_service_url"
    def local_service(service, port)
      update_service_url(service, local_service_url(port))
    end

    desc "local_et1 PORT", "Configures the reverse proxy and the invoker system to allow a developer to run the web server and sidekiq locally"
    def local_et1(port)
      local_service('et1', port)
      invoker 'remove', 'et1_web'
      invoker 'remove', 'et1_sidekiq'
      puts "ET1 is now expected to be hosted on port #{port} on your machine. To configure your environment, run 'et_full_system docker et1_env > .env.local'"
    end

    desc "reset_et1", "Configures the reverse proxy and invoker to use the internal systems instead of local"
    def reset_et1
      invoker 'add', 'et1_web'
      invoker 'add', 'et1_sidekiq'
      puts "ET1 is now being hosted from inside docker container"
    end

    desc "et1_env", "Shows et1's environment variables as they should be on a developers machine running locally"
    def et1_env
      service_env('et1')
    end

    desc "service_env SERVICE", "Returns the environment variables configured for the specified service"
    def service_env(service)
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "/bin/bash --login -c \"et_full_system local service_env #{service}\""
        compose_cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml exec et #{cmd}"
        result = `#{compose_cmd}`
        replace_db_host_port(result)
        replace_redis_host_port(result)
        replace_smtp_host_port(result)
        puts result
      end
    end

    private

    def run_compose_command(*args, silent: false)
      Bundler.with_original_env do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "GEM_VERSION=#{EtFullSystem::VERSION} docker-compose -f #{gem_root}/docker/docker-compose.yml #{args.join(' ')}"
        puts cmd unless silent
        `#{cmd}`
      end
    end

    def host_ip
      result = JSON.parse `docker network inspect \`docker network list | grep docker_et_full_system | awk '{print $1}'\``
      result.first.dig('IPAM', 'Config').first['Gateway']
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

    def replace_db_host_port(env)
      env.gsub!(/^DB_HOST=.*$/, 'DB_HOST=localhost')
      env.gsub!(/^DB_PORT=.*$/, "DB_PORT=#{db_port}")
    end

    def replace_redis_host_port(env)
      env.gsub!(/^REDIS_HOST=.*$/, 'REDIS_HOST=localhost')
      env.gsub!(/^REDIS_PORT=.*$/, "REDIS_PORT=#{redis_port}")
    end

    def replace_smtp_host_port(env)
      env.gsub!(/^SMTP_HOSTNAME=.*$/, 'SMTP_HOSTNAME=localhost')
      env.gsub!(/^SMTP_PORT=.*$/, "SMTP_PORT=#{smtp_port}")
    end

    def db_port
      result = run_compose_command :port, :db, 5432, silent: true
      result.split(':').last.strip
    end

    def redis_port
      result = run_compose_command :port, :redis, 6379, silent: true
      result.split(':').last.strip
    end

    def smtp_port
      result = run_compose_command :port, :et, 1025, silent: true
      result.split(':').last.strip
    end
  end
end
