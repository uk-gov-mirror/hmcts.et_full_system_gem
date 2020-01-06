module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  require "rubygems"
  require "thor"
  require 'httparty'
  require 'et_full_system/cli/local/file_storage'
  require 'dotenv'

  class LocalCommand < Thor
    DEFAULT_BASE_URL="http://localhost:3200"
    LOCK_FILE = File.join(Dir.tmpdir, 'et_full_system_traefik_rest_lockfile')
    PROJECT_PATH = Dir.pwd
    GEM_PATH = File.absolute_path('../../..', __dir__)

    class RestProviderNotConfigured < RuntimeError; end
    class ServiceUrlIncorrect < RuntimeError; end
    desc "boot", "Sets up the server - traefik frontends and backends, along with initial data in local s3 and azure storage"
    method_option :base_url, type: :string, default: DEFAULT_BASE_URL
    def boot
      STDERR.puts "boot - base_url is #{options[:base_url]}"
      json_setup_file = File.absolute_path('../../../foreman/traefik.json', __dir__)
      connect_retry_countdown = 10
      begin
        resp = HTTParty.put "#{options[:base_url]}/api/providers/rest", body: File.read(json_setup_file) , headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}
        raise "Error from traefik when performing initial config says: #{resp.body}" unless (200..299).include? resp.code
        sleep 1
      rescue Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED
        connect_retry_countdown -= 1
        if connect_retry_countdown.zero?
          raise "Could not connect to the traefik API after 10 retries (boot)"
        else
          STDERR.puts "boot - Retrying connection to traefik API in 5 seconds"
          sleep 5
          retry
        end
      end
    end

    method_option :base_url, type: :string, default: DEFAULT_BASE_URL
    method_option :wait, type: :boolean, default: false, desc: "If set, the command will retry up to 10 times at 5 second intervals to connect to traefik.  If not set, will fail immediately"
    desc "update_service_url SERVICE URL", "Configures the reverse proxy to connect to a specific url for a service"
    def update_service_url(service, url)
      within_rest_lock do
        update_rest_backend_url(service, url)
      end
    end

    method_option :base_url, type: :string, default: DEFAULT_BASE_URL
    desc "wait_for_support", "Waits for the servers support services to be ready - useful to call before starting application services"
    def wait_for_support
      connect_retry_countdown = 10
      setup_retry_countdown = 10

      begin
        resp = HTTParty.get "#{options[:base_url]}/api/providers/rest", headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}
        raise RestProviderNotConfigured if resp.code == 404
      rescue Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED
        connect_retry_countdown -= 1
        if connect_retry_countdown.zero?
          raise "Could not connect to the traefik API after 10 retries (wait_for_support)"
        else
          STDERR.puts "wait_for_support - Retrying connection to traefik API in 5 seconds"
          sleep 5
          retry
        end
      rescue RestProviderNotConfigured
        setup_retry_countdown -= 1
        if setup_retry_countdown.zero?
          raise "Could not find the REST provider in traefik after 10 retries"
        else
          STDERR.puts "Re checking for the REST provider in traefik in 5 seconds"
          sleep 5
          retry
        end
      end
      STDERR.puts "Support services now ready"
    end


    desc "server", "Starts the full system server"
    method_option :without, type: :array, default: [], banner: "service1 service2", desc: "If specified, disables the specified services from running. The services are et1_web, et1_sidekiq, et3_web, mail_web, api_web, api_sidekiq, admin_web, atos_api_web, s3_web, azure_blob_web, fake_acas_web"
    method_option :azurite_storage_path, default: ENV.fetch('AZURITE_STORAGE_PATH', '/tmp/azurite_storage'), desc: "Where to store azurite data"
    method_option :minio_storage_path, default: ENV.fetch('MINIO_STORAGE_PATH', '/tmp/minio_storage'), desc: "Where to store minio data"
    method_option :rails_env, type: :string, default: ENV.fetch('RAILS_ENV', 'production')
    method_option :cloud_provider, type: :string, default: ENV.fetch('CLOUD_PROVIDER', 'amazon')
    def server
      puts "Scheduling traefik config and file storage config"
      pid = fork do
        self.class.start(['boot'])
        EtFullSystem::Cli::Local::FileStorageCommand.start(['setup'])
      end
      Process.detach(pid)

      puts "Starting Procfile"
      ::Bundler.with_original_env do
        concurrency = " -c #{procfile_concurrency_without(options[:without]).join(',')}"
        cmd = "CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} AZURITE_STORAGE_PATH=\"#{options[:azurite_storage_path]}\" MINIO_STORAGE_PATH=\"#{options[:minio_storage_path]}\" FS_ROOT_PATH=#{PROJECT_PATH} FOREMAN_PATH=#{GEM_PATH}/foreman godotenv -f #{GEM_PATH}/foreman/.env invoker start \"#{GEM_PATH}/foreman/Procfile\" --port=4000"
        STDERR.puts cmd
        exec(cmd)
      end
    end

    desc "file_storage <commands>", "Tools for the 'local cloud' file storage"
    subcommand "file_storage", ::EtFullSystem::Cli::Local::FileStorageCommand

    desc "setup", "Sets up everything ready for first run"
    method_option :rails_env, type: :string, default: ENV.fetch('RAILS_ENV', 'production')
    method_option :cloud_provider, type: :string, default: ENV.fetch('CLOUD_PROVIDER', 'amazon')
    def setup
      setup_depencencies
      setup_services
    end

    desc "setup_services", "Sets up all services in one command"
    def setup_services
      ::Bundler.with_original_env do
        setup_et1_service
        setup_et3_service
        setup_api_service
        setup_admin_service
        setup_atos_service
        setup_ccd_service
      end
    end

    desc "setup_dependencies", "Sets up all local dependencies"
    def setup_depencencies
      cmd = "bash --login -c \"cd /tmp && git clone https://github.com/ministryofjustice/et_fake_acas_server.git && cd et_fake_acas_server && gem build -o et_fake_acas_server.gem et_fake_acas_server && gem install et_fake_acas_server.gem && cd .. && rm -rf et_fake_acas_server\""
      STDERR.puts cmd
      external_command cmd, 'setup_dependencies'
    end

    desc "service_env SERVICE", "Returns the environment variables configured for the specified service"
    def service_env(service)
      lookup = {
        'atos_api' => :et_atos,
        'admin' => :et_admin,
        'api' => :et_api,
        'et1' => :et1,
        'et3' => :et3,
        'et_ccd_export' => :et_ccd_export
      }
      file = lookup.fetch(service)
      parsed = Dotenv.parse("#{GEM_PATH}/foreman/.env", "#{GEM_PATH}/foreman/#{file}.env")
      parsed.each_pair do |name, value|
        puts "#{name}=#{value}"
      end
    rescue KeyError
      puts "The service must be one of #{lookup.keys}"
    end

    private

    def procfile_services
      File.readlines("#{GEM_PATH}/foreman/Procfile").inject([]) do |acc, line|
        next if line.strip.start_with?('#')
        acc + [line.split(':').first]
      end
    end

    def procfile_concurrency_without(without)
      procfile_services.map {|service| "#{service}=#{without.include?(service) ? 0 : 1}"}
    end

    def external_command(cmd, tag)
      IO.popen(cmd) do |io|
        io.each do |line|
          puts "| #{tag} | #{line}"
        end
      end
    end

    def setup_et1_service
      puts "------------------------------------------------ SETTING UP ET1 SERVICE ---------------------------------------------------"
      cmd = "bash --login -c \"cd #{PROJECT_PATH}/systems/et1 && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et1.env\" bundle install --with=#{options[:rails_env]}\""
      puts cmd
      external_command cmd, 'et1 setup'

      cmd = "bash --login -c \"cd #{PROJECT_PATH}/systems/et1 && npm install\""
      puts cmd
      external_command cmd, 'et1 setup'

      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/et1 && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et1.env\" bundle exec rake db:create db:migrate assets:precompile\""
      puts cmd
      external_command cmd, 'et1 setup'
    end

    def setup_et3_service
      puts "------------------------------------------------ SETTING UP ET3 SERVICE ---------------------------------------------------"
      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/et3 && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et3.env\" bundle install --with=#{options[:rails_env]}\""
      puts cmd
      external_command cmd, 'et3 setup'

      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/et3 && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et3.env\" bundle exec rake db:create db:migrate assets:precompile\""
      puts cmd
      external_command cmd, 'et3 setup'
    end

    def setup_admin_service
      puts "------------------------------------------------ SETTING UP ADMIN SERVICE ---------------------------------------------------"
      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/admin && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et_admin.env\" bundle install --with=#{options[:rails_env]}\""
      puts cmd
      external_command cmd, 'admin setup'

      puts "|   Admin    | Running rake commands"
      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/admin && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et_admin.env\" bundle exec rake db:seed assets:precompile\""
      puts cmd
      external_command cmd, 'admin setup'
    end

    def setup_api_service
      puts "------------------------------------------------ SETTING UP API SERVICE ---------------------------------------------------"
      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/api && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et_api.env\" bundle install --with=#{options[:rails_env]}\""
      puts cmd
      external_command cmd, 'api setup'

      puts "|   API      | Running rake commands"
      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/api && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et_api.env\" bundle exec rake db:create db:migrate db:seed\""
      puts cmd
      external_command cmd, 'api setup'
    end

    def setup_atos_service
      puts "------------------------------------------------ SETTING UP ATOS SERVICE ---------------------------------------------------"
      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/atos && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et_atos.env\" bundle install --with=#{options[:rails_env]}\""
      puts cmd
      external_command cmd, 'atos setup'
    end
    
    def setup_ccd_service
      puts "------------------------------------------------ SETTING UP CCD EXPORT SERVICE ---------------------------------------------------"
      cmd ="bash --login -c \"cd #{PROJECT_PATH}/systems/et_ccd_export && CLOUD_PROVIDER=#{options[:cloud_provider]} RAILS_ENV=#{options[:rails_env]} godotenv -f \"#{GEM_PATH}/foreman/.env\" godotenv -f \"#{GEM_PATH}/foreman/et_ccd_export.env\" bundle install --with=#{options[:rails_env]}\""
      puts cmd
      external_command cmd, 'ccd setup'
    end

    def update_rest_backend_url(service, url)
      connect_retry_countdown = 10
      setup_retry_countdown = 10
      begin
        resp = HTTParty.get "#{options[:base_url]}/api/providers/rest", headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
        raise RestProviderNotConfigured if resp.code == 404
      rescue Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED
        connect_retry_countdown -= 1
        if !options[:wait]
          fail "Could not connect to the traefik API - specify --wait to keep retrying when this happens"
        elsif connect_retry_countdown.zero?
          fail "Could not connect to the traefik API after 10 retries (update_rest_backend_url)"
        else
          STDERR.puts "update_rest_backend_url - Retrying connection to traefik API in 5 seconds"
          sleep 5
          retry
        end
      rescue RestProviderNotConfigured
        setup_retry_countdown -= 1
        if !options[:wait]
          fail "The REST provider in traefik is not yet setup - specify --wait to keep retrying when this happens (i.e to wait for another command to set it up)"
        elsif setup_retry_countdown.zero?
          fail "Could not find the REST provider in traefik after 10 retries"
        else
          STDERR.puts "Re checking for the REST provider in traefik in 5 seconds"
          sleep 5
          retry
        end
      end

      json = resp.parsed_response.dup
      backend = json['backends'][service]
      raise "Unknown service called #{service} - valid options are #{json['backends'].keys.join(', ')}" if backend.nil?

      container = backend.dig('servers', 'web')
      raise "The service '#{service}' has no server called 'web' - it must have for this command to work" if container.nil?

      if container['url'] != url
        container['url'] = url
        put_resp = HTTParty.put "#{options[:base_url]}/api/providers/rest", body: json.to_json, headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
        raise "Error from traefik says: #{put_resp.body}" unless (200..299).include? put_resp.code

        validate_rest_backend_url(service, url)
        STDERR.puts "The url for service '#{service}' is now '#{url}'"
      else
        STDERR.puts "The url for service '#{service}' was already '#{url}'"
      end
    end

    def validate_rest_backend_url(service, url)
      retry_countdown = 10
      begin
        resp = HTTParty.get "#{options[:base_url]}/api/providers/rest", headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
        raise ServiceUrlIncorrect unless (200..299).include?(resp.code) && resp.parsed_response.dig('backends', service, 'servers', 'web', 'url') == url
        return
      rescue ServiceUrlIncorrect
        retry_countdown -= 1
        raise if retry_countdown.zero?

        STDERR.puts "Retrying request to validate the url of '#{service}' is '#{url}' in 1 second"
        sleep 1
        retry
      end
    end

    def within_rest_lock(wait: 60 * 60 * 24, timeout: 60)
      File.open(LOCK_FILE, File::RDWR|File::CREAT, 0644) do |file|
        Timeout::timeout(wait) { file.flock(File::LOCK_EX) }
        Timeout::timeout(timeout) { yield file }
      end
    end

    def summarise_json(json)
      json['backends'].inject({}) do |acc, (service, value)|
        acc[service] = value.dig('servers', 'web', 'url')
        acc
      end
    end
  end
end
