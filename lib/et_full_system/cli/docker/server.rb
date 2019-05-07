require 'bundler'
module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  module Cli
    module Docker
      class ServerCommand < Thor
        BEFORE_BOOT_SCRIPT =
        desc "up", "Starts the full system server on docker"
        method_option :without, type: :array, default: [], banner: "service1 service2", desc: "If specified, disables the specified services from running. The services are et1_web, et1_sidekiq, et3_web, mail_web, api_web, api_sidekiq, admin_web, atos_api_web, s3_web, azure_blob_web, fake_acas_web"
        def up(*args)
          Bundler.with_original_env do
            server_args = []
            server_args << "--without=#{options[:without].join(' ')}" unless options[:without].empty?
            env_vars = "SERVER_ARGS='#{server_args.join(' ')}'"
            gem_root = File.absolute_path('../../../..', __dir__)
            cmd = "#{env_vars} docker-compose -f #{gem_root}/docker/docker-compose.yml up #{args.join(' ')}"
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
