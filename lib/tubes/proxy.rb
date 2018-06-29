require 'eventmachine'
require 'http/parser'
require 'uuid'
require 'diplomat'
require 'ipaddr'
require 'prometheus/client'


module Tubes

  class SelectedService
    attr_reader :ip, :port, :tls, :extra_labels

    def initialize(host_header, cidr)
      @ip = nil

      services = Diplomat::Service.get(host_header.split(".").first, scope=:all)
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
        @tls = { sni_hostname: host_header }
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


  class Proxy

    def self.run(host, port, cidr)
      cidr = IPAddr.new(cidr)
      puts "listening on #{host}:#{port} from #{cidr}"
      registry = Prometheus::Client.registry

      performance_histo = registry.histogram(:tubes_proxy_request_performance, "Time to complete requests")
      tubes_proxy_bytes_sent = registry.counter(:tubes_proxy_bytes_sent, "Number of bytes sent to client")
      tubes_proxy_bytes_recv = registry.counter(:tubes_proxy_bytes_recv, "Number of bytes received from client")

      EventMachine::start_server(host, port, Tubes::ServerConnection, {registry: Prometheus::Client.registry, debug: false}) do |conn|
        connection_start = Time.now
        buffer = ''
        headers_complete = false
        request_labels = {service: :unknown, nomad_job: :unknown}

        header_parser = Http::Parser.new
        header_parser.on_headers_complete = proc do |headers|
          session = UUID.generate

          begin
            selected_service = SelectedService.new(headers['Host'], cidr)
            print "#{session}: ( #{headers['Host']} )"

            if selected_service.present?
              ip = selected_service.ip
              port = selected_service.port
              tls = selected_service.tls
              puts " proxying to: '#{ip}:#{port}'"
              conn.server(session, :host => ip, :port => port, :tls => tls)
              request_labels.merge!(selected_service.extra_labels)

              begin
                tubes_proxy_bytes_recv.increment(labels=request_labels, by=buffer.bytesize)
              rescue Prometheus::Client::LabelSetValidator::LabelSetError => e
                p e
              end

              conn.relay_to_servers( buffer)
            else
              puts ". No backend registered for #{tubes_host}"
              conn.unbind
              conn.close_connection
            end
          rescue StandardError => se
            puts ". Error proxying: " + se.to_s
            conn.unbind
            conn.close_connection
          ensure
            STDOUT.flush
            buffer.clear
            headers_complete = true
          end
        end
        conn.on_response do |name, data|
          begin
            tubes_proxy_bytes_sent.increment(labels=request_labels, by=data.bytesize)
          rescue Prometheus::Client::LabelSetValidator::LabelSetError => e
            p e
          end

          data
        end

        conn.on_data do |data|
          unless headers_complete
            buffer << data
            header_parser << data
            nil
          else
            begin
              tubes_proxy_bytes_recv.increment(labels=request_labels, by=data.bytesize)
            rescue Prometheus::Client::LabelSetValidator::LabelSetError => e
              p e
            end
            data
          end
        end

        conn.on_finish do
          delta = Time.now - connection_start
          begin
            performance_histo.observe(request_labels, delta)
          rescue Prometheus::Client::LabelSetValidator::LabelSetError => e
            p e
          end
        end
      end
    end
  end
end
