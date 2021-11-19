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
      unbundled do
        cmd = File.absolute_path('../../../shell_scripts/docker_bootstrap.sh', __dir__)
        puts cmd
        exec(cmd)
      end
    end

    desc "setup", "Sets up the system for initial run - or after changing branches, adding gems etc.. in any of the services"
    def setup
      unbundled do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "/bin/bash --login -c \"cd /home/app/full_system && et_full_system docker bootstrap && et_full_system local setup --in-docker-compose\""
        compose_cmd = "UID=#{Process.uid} GEM_VERSION=#{EtFullSystem::VERSION} LOCALHOST_FROM_DOCKER_IP=#{host_ip} docker-compose -f #{gem_root}/docker/docker-compose.yml run --rm et #{cmd}"
        puts compose_cmd
        exec(compose_cmd)
      end
    end

    desc "compose", "Provides access to the docker-compose command"
    def compose(*args)
      unbundled do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "UID=#{Process.uid} GEM_VERSION=#{EtFullSystem::VERSION} LOCALHOST_FROM_DOCKER_IP=#{host_ip} docker-compose -f #{gem_root}/docker/docker-compose.yml #{args.join(' ')}"
        puts cmd
        exec(cmd)
      end
    end

    desc "invoker", "Provides access to the invoker system running inside docker"
    def invoker(*args)
      run_on_local("invoker #{args.join(' ')}")
    end

    desc "reset", "Bring down the server, remove all caches, rebuild the Dockerfile etc..."
    def reset
      unbundled do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "UID=#{Process.uid} GEM_VERSION=#{EtFullSystem::VERSION} LOCALHOST_FROM_DOCKER_IP=#{host_ip} docker-compose -f #{gem_root}/docker/docker-compose.yml down -v"
        puts cmd
        next unless system(cmd)
        cmd = "UID=#{Process.uid} GEM_VERSION=#{EtFullSystem::VERSION} LOCALHOST_FROM_DOCKER_IP=#{host_ip} docker-compose -f #{gem_root}/docker/docker-compose.yml build --no-cache"
        puts cmd
        next unless system(cmd)
        self.class.start(['setup'])
      end
    end

    desc "update_service_url SERVICE URL", "Configures the reverse proxy to connect to a specific url for a service - note the URL must be reachable from the docker container and the server must be running"
    def update_service_url(service, url)
      run_on_local("update_service_url #{service} #{url}")
    end

    desc "local_service SERVICE PORT", "Configures the reverse proxy to connect to a specific port on the host machine - the URL is calculated - otherwise it is the same as update_service_url"
    def local_service(service, port)
      update_service_url(service, local_service_url(port))
    end

    desc "local_et1 PORT", "Configures the reverse proxy and the invoker system to allow a developer to run the web server and sidekiq locally"
    def local_et1(port)
      local_service('et1', port)
      disable_et1
      puts "ET1 is now expected to be hosted on port #{port} on your machine. To configure your environment, run 'et_full_system docker et1_env > .env'"
    end


    desc "et1_env", "Shows et1's environment variables as they should be on a developers machine running locally"
    def et1_env
      service_env('et1')
    end

    desc "local_ccd_export", "Disables the sidekiq process in the invoker system to allow a developer to run it locally"
    def local_ccd_export
      run_on_local('disable_ccd_export')
      puts "ccd_export is now expected to be running on your machine. To configure your environment, run 'et_full_system docker ccd_export_env > .env'"
    end

    desc "ccd_export_env", "Shows ccd_export's environment variables as they should be on a developers machine running locally"
    def ccd_export_env
      service_env('et_ccd_export')
    end

    desc "local_api PORT", "Configures the reverse proxy and the invoker system to allow a developer to run the web server and sidekiq locally"
    def local_api(port)
      local_service('api', port)
      disable_api
      puts "api is now expected to be hosted on port #{port} on your machine. Also, you must provide your own sidekiq. To configure your environment, run 'et_full_system docker api_env > .env'"
    end

    desc "api_env", "Shows api's environment variables as they should be on a developers machine running locally"
    def api_env
      service_env('api')
    end

    desc "local_admin PORT", "Configures the reverse proxy and the invoker system to allow a developer to run the admin web server locally"
    def local_admin(port)
      local_service('admin', port)
      disable_admin
      puts "Admin is now expected to be hosted on port #{port} on your machine. To configure your environment, run 'et_full_system docker admin_env > .env'"
    end

    desc "admin_env", "Shows admin's environment variables as they should be on a developers machine running locally"
    def admin_env
      service_env('admin')
    end

    desc "local_et3 PORT", "Configures the reverse proxy and the invoker system to allow a developer to run the et3 web server locally"
    def local_et3(port)
      local_service('et3', port)
      disable_et3
      puts "ET3 is now expected to be hosted on port #{port} on your machine. To configure your environment, run 'et_full_system docker et3_env > .env'"
    end


    desc "et3_env", "Shows et3's environment variables as they should be on a developers machine running locally"
    def et3_env
      service_env('et3')
    end

    desc "service_env SERVICE", "Returns the environment variables configured for the specified service"
    def service_env(service)
      result = run_on_local("service_env #{service}", return_output: true)
      replace_db_host_port(result)
      replace_redis_host_port(result)
      replace_smtp_host_port(result)
      puts result
    end

    desc "enable_et1", "Configures the reverse proxy and invoker to use the internal systems instead of local"
    def enable_et1
      run_on_local("enable_et1")
    end

    desc "enable_ccd_export", "Configures invoker to use the internal systems instead of local"
    def enable_ccd_export
      run_on_local("enable_ccd_export")
    end

    desc "enable_atos_api", "Configures invoker to use the internal systems instead of local"
    def enable_atos_api
      run_on_local("enable_atos_api")
    end

    desc "enable_api", "Configures the reverse proxy and invoker to use the internal systems instead of local"
    def enable_api
      run_on_local("enable_api")
    end

    desc "enable_admin", "Configures the reverse proxy and invoker to use the internal systems instead of local"
    def enable_admin
      run_on_local("enable_admin")
    end

    desc "enable_et3", "Configures the reverse proxy and invoker to use the internal systems instead of local"
    def enable_et3
      run_on_local("enable_et3")
    end

    desc "disable_et1", "Stops et1 from running in the stack"
    def disable_et1
      run_on_local("disable_et1")
    end

    desc "disable_ccd_export", "Stops ccd_export from running in the stack"
    def disable_ccd_export
      run_on_local("disable_ccd_export")
    end

    desc "disable_atos_api", "Stops atos_api running in the stack"
    def disable_atos_api
      run_on_local("disable_atos_api")
    end

    desc "disable_api", "Stops api from running in the stack"
    def disable_api
      run_on_local("disable_api")
    end

    desc "disable_admin", "Stops admin from running in the stack"
    def disable_admin
      run_on_local("disable_admin")
    end

    desc "disable_et3", "Stops et3 from running in the stack"
    def disable_et3
      run_on_local("disable_et3")
    end

    desc "restart_et1", "Restarts the et1 application"
    def restart_et1
      run_on_local("restart_et1")
    end

    desc "restart_api", "Restarts the api application"
    def restart_api
      run_on_local("restart_api")
    end

    desc "restart_et3", "Restarts the et3 application"
    def restart_et3
      run_on_local("restart_et3")
    end

    desc "restart_admin", "Restarts the admin application"
    def restart_admin
      run_on_local("restart_admin")
    end

    desc "restart_atos_api", "Restarts the atos_api application"
    def restart_atos_api
      run_on_local("restart_atos_api")
    end

    desc "restart_ccd_export", "Restarts the ccd_export application"
    def restart_ccd_export
      run_on_local("restart_ccd_export")
    end

    private

    def unbundled(&block)
      method = Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_original_env
      Bundler.send(method, &block)
    end

    def run_on_local(cmd, return_output: false)
      unbundled do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "/bin/bash --login -c \"et_full_system local #{cmd}\""
        compose_cmd = "UID=#{Process.uid} GEM_VERSION=#{EtFullSystem::VERSION} LOCALHOST_FROM_DOCKER_IP=#{host_ip} docker-compose -f #{gem_root}/docker/docker-compose.yml exec et #{cmd}"
        if return_output
          `#{compose_cmd}`
        else
          system(compose_cmd)
        end
      end
    end

    def run_compose_command(*args, silent: false)
      unbundled do
        gem_root = File.absolute_path('../../..', __dir__)
        cmd = "UID=#{Process.uid} GEM_VERSION=#{EtFullSystem::VERSION} LOCALHOST_FROM_DOCKER_IP=#{host_ip} docker-compose -f #{gem_root}/docker/docker-compose.yml #{args.join(' ')}"
        puts cmd unless silent
        `#{cmd}`
      end
    end

    def host_ip
      result = JSON.parse `docker network inspect docker_et_full_system`
      return '0.0.0.0' if result.empty?

      result.first.dig('IPAM', 'Config').first['Gateway']
    end

    def local_service_url(port)
      case ::EtFullSystem.os
      when :linux, :unix
        "http://#{host_ip}:#{port}"
      when :macosx
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
