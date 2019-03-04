require 'eventmachine'
require 'http/parser'
require 'uuid'
require 'diplomat'
require 'ipaddr'
require 'prometheus/client'
require 'active_support'

module Tubes

  class SelectedService
    attr_reader :ip, :port, :tls, :service_name, :fqdn, :extra_labels

    def self.get_services(service_name)
      @cache ||= ActiveSupport::Cache::MemoryStore.new

      @cache.fetch(service_name, expires_in: 1.second) do
        Diplomat::Service.get(service_name, scope=:all)
      end
    end


    def initialize(headers, cidr)
      @fqdn = headers['Host']
      @service_name = @fqdn.split(".").first
      @tls = false
      @extra_labels = {}
      @sni_hostname = headers['Sni-Host'] || @fqdn
      
      services = SelectedService.get_services(service_name)
      service = services.select {|s| cidr.include?(s.ServiceAddress) }.sample
      random_service = services.sample
      if service
        @ip = service.ServiceAddress
        @port = service.ServicePort
        @tls = false
        @extra_labels = service_labels(service)
        @extra_labels[:proxy_type] = 'local'
      elsif random_service
        @ip = random_service.ServiceAddress
        @port = "443"
        @tls = { sni_hostname: @sni_hostname }
        @extra_labels = service_labels(random_service)
        @extra_labels[:proxy_type] = 'remote'
      end
    end

    def present?
      !@ip.nil?
    end

    private

    def service_labels(service)
      job_name_tag = service.ServiceTags.find {|tag| tag.start_with?("tubes-job-name:")}

      labels = { service: service.ServiceName }
      labels[:nomad_job] = job_name_tag.split(":")[1] unless job_name_tag.nil?

      return labels
    end

  end

  module TLSProxyConnection
    def initialize(client, request, sni_hostname)
      #puts "TLSProxyConnection"
      @client = client
      @request = request
      @sni_hostname = sni_hostname
      @server_cert = []
      @cert_store = OpenSSL::X509::Store.new
      @cert_store.set_default_paths
    end

    def post_init
      start_tls :verify_peer => true, :sni_hostname => @sni_hostname
    end

    def ssl_handshake_completed
      cert_to_check = @server_cert.reverse.inject("") do |v, cert|
        v += cert
      end
      certificate = OpenSSL::X509::Certificate.new(cert_to_check)

      unless OpenSSL::SSL.verify_certificate_identity(certificate, @sni_hostname)
        close_connection
      end
      send_data @request
      EM::enable_proxy(self, @client)
    end

    def ssl_verify_peer(cert)
      @server_cert << cert

      cert_to_check = @server_cert.inject("") { |v, cert| v += cert }
      
      certificate = OpenSSL::X509::Certificate.new(cert_to_check)

      @cert_store.verify(certificate)
    end

    def connection_completed
      send_data @request
    end

    def proxy_target_unbound
      close_connection
    end

    def unbind
      @client.close_connection_after_writing
    end
  end

  module ProxyConnection
    def initialize(client, request)
      @client, @request = client, request
    end

    def post_init
      EM::enable_proxy(self, @client)
    end

    def connection_completed
      send_data @request
    end

    def proxy_target_unbound
      close_connection
    end

    def unbind
      @client.close_connection_after_writing
    end
  end

  class ProxyServer < EventMachine::Connection


    ##### EventMachine
    def initialize(options)
      @debug = options[:debug] || false
      @registry = options[:registry]
      @header_parser = Http::Parser.new
      @header_parser.on_headers_complete = proc do |headers|
        session = UUID.generate

        begin
          selected_service = SelectedService.new(headers, @cidr)
          print "#{session}: ( #{selected_service.service_name} )"

          if selected_service.present?
            ip = selected_service.ip
            port = selected_service.port
            puts " proxying to: '#{ip}:#{port}'"
            if (selected_service.tls)
              EventMachine.connect(ip, port, Tubes::TLSProxyConnection, self, @buf, selected_service.tls[:sni_hostname])
            else
              EventMachine.connect(ip, port, Tubes::ProxyConnection, self, @buf)
            end
          else
            puts ". No backend registered for #{selected_service.fqdn}"
            close_connection
          end
        ensure
          STDOUT.flush
        end
      end

      @cidr = options[:cidr]
      @buf = ""
    end

    def receive_data(data)
      @buf << data
      @header_parser << data
    end
  end

  class Proxy

    def self.run(host, port, cidr)
      puts "listening on #{host}:#{port} from #{cidr}"

      EventMachine::start_server(host, port, Tubes::ProxyServer, {cidr: IPAddr.new(cidr), debug: true})# do |conn|
    end
  end
end
