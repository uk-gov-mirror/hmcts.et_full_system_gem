require 'bundler'
module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  module Cli
    module Docker
      class ServerCommand < Thor
        BEFORE_BOOT_SCRIPT =
        desc "up", "Starts the full system server on docker"
        method_option :without, type: :array, default: [], banner: "service1 service2", desc: "If specified, disables the specified services from running. The services are et1_web, et1_sidekiq, et3_web, mail_web, api_web, api_sidekiq, admin_web, atos_api_web, s3_web, azure_blob_web, fake_acas_web, fake_ccd_web"
        method_option :ccd_docker, type: :boolean, default: false, aliases: 'ccd-docker', desc: "If specified, instead of using the built in fake ccd server, the system will connect to your local machine (see ccd-docker-host option also)"
        method_option :ccd_docker_host, type: :string, default: 'docker.for.mac.localhost', aliases: 'ccd-docker-host', desc: "Only used if ccd-docker=true.  This specifies the host name of your machine when viewed from inside the docker container.  This defaults to docker.for.mac.localhost which is suitable for mac OSX only.  Consult docker documentation for other systems"
        def up(*args)
          Bundler.with_original_env do
            server_args = []
            server_args << "--without=#{options[:without].join(' ')}" unless options[:without].empty?
            env_vars = ["SERVER_ARGS='#{server_args.join(' ')}'"]
            if options.ccd_docker?
              env_vars << "CCD_AUTH_BASE_URL=http://#{options.ccd_docker_host}:4502"
              env_vars << "CCD_IDAM_BASE_URL=http://#{options.ccd_docker_host}:4501"
              env_vars << "CCD_DATA_STORE_BASE_URL=http://#{options.ccd_docker_host}:4452"
              env_vars << "CCD_USE_SIDAM=false"
            end

            gem_root = File.absolute_path('../../../..', __dir__)
            cmd = "#{env_vars.join(' ')} docker-compose -f #{gem_root}/docker/docker-compose.yml up #{args.join(' ')}"
            puts cmd
            exec(cmd)
          end
        end

        desc "down", "Stops the full system server on docker"
        def down(*args)
          ::Bundler.with_original_env do
            gem_root = File.absolute_path('../../../..', __dir__)
            cmd = "docker-compose -f #{gem_root}/docker/docker-compose.yml down #{args.join(' ')}"
            puts cmd
            exec(cmd)
          end
        end

        default_task :up
      end
    end
  end
end
