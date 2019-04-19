module EtFullSystem
  #!/usr/bin/env ruby
  # frozen_string_literal: true
  require "rubygems"
  require "thor"
  require 'httparty'
  require 'et_full_system/cli/file_storage'

  class LocalCommand < Thor
    DEFAULT_BASE_URL="http://localhost:3200"
    LOCK_FILE = File.join(Dir.tmpdir, 'et_full_system_traefik_rest_lockfile')
    class RestProviderNotConfigured < RuntimeError; end
    class ServiceUrlIncorrect < RuntimeError; end
    desc "setup", "Sets up the server - traefik frontends and backends, along with initial data in local s3 and azure storage"
    method_option :base_url, type: :string, default: DEFAULT_BASE_URL
    def setup
      json_setup_file = File.absolute_path('../../../foreman/traefik.json', __dir__)
      connect_retry_countdown = 10
      begin
        resp = HTTParty.put "#{options[:base_url]}/api/providers/rest", body: File.read(json_setup_file) , headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}
        raise "Error from traefik when performing initial config says: #{put_resp.body}" unless (200..299).include? resp.code
        sleep 1
      rescue Errno::EADDRNOTAVAIL
        connect_retry_countdown -= 1
        if connect_retry_countdown.zero?
          raise "Could not connect to the traefik API after 10 retries"
        else
          STDERR.puts "Retrying connection to traefik API in 5 seconds"
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
      rescue Errno::EADDRNOTAVAIL
        connect_retry_countdown -= 1
        if connect_retry_countdown.zero?
          raise "Could not connect to the traefik API after 10 retries"
        else
          STDERR.puts "Retrying connection to traefik API in 5 seconds"
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
    def server
      Bundler.with_original_env do
        cmd = File.absolute_path('../../../shell_scripts/run_foreman', __dir__)
        STDERR.puts cmd
        exec(cmd)

      end
    end

    desc "file_storage <commands>", "Tools for the 'local cloud' file storage"
    subcommand "file_storage", ::EtFullSystem::FileStorageCommand

    private

    def update_rest_backend_url(service, url)
      connect_retry_countdown = 10
      setup_retry_countdown = 10
      begin
        resp = HTTParty.get "#{options[:base_url]}/api/providers/rest", headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
        raise RestProviderNotConfigured if resp.code == 404
      rescue Errno::EADDRNOTAVAIL
        connect_retry_countdown -= 1
        if !options[:wait]
          fail "Could not connect to the traefik API - specify --wait to keep retrying when this happens"
        elsif connect_retry_countdown.zero?
          fail "Could not connect to the traefik API after 10 retries"
        else
          STDERR.puts "Retrying connection to traefik API in 5 seconds"
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
