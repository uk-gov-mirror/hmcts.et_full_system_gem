module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  require "rubygems"
  require "thor"
  require 'azure/storage'

  module Cli
    module Local
      class FileStorageCommand < Thor
        GEM_PATH = File.absolute_path('../../../..', __dir__)

        desc "setup", "Primes the storage account(s) for running locally - i.e. using local Azure Blob storage"
        def setup_storage
          setup_azure_storage
        end

        private

        def unbundled(&block)
          method = Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_original_env
          Bundler.send(method, &block)
        end

        def setup_azure_storage
          unbundled do
            puts `bash --login -c "export RAILS_ENV=production && cd systems/api && godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et_api.env\" bundle exec rails configure_azure_storage_containers configure_azure_storage_cors"`

          end
        end
      end
    end
  end
end
