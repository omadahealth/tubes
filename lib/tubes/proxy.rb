require 'em-proxy'
require 'http/parser'
require 'uuid'
require 'diplomat'
require 'ipaddr'

module Tubes
  class Proxy
    attr_accessor :host, :port

    def initialize(host, port, cidr)
      @host = host
      @port = port
      @cidr = IPAddr.new(cidr)
    end


    def run
      puts "listening on #{host}:#{port}..."
      cidr = @cidr
      ::Proxy.start(:host => host, :port => port) do |conn|
        buffer = ''
        headers_complete = false

        header_parser = Http::Parser.new
        header_parser.on_headers_complete = proc do |headers|
          session = UUID.generate

          begin
            tubes_host = headers['Host'].split(':').first.split(".").first
            print "#{session}: ( #{headers['Host']}#{header_parser.request_url} )"
            services = Diplomat::Service.get(tubes_host, scope=:all)
            service = services.select {|s| cidr.include?(s.ServiceAddress) }.sample
            host = service.ServiceAddress
            port = service.ServicePort

            puts " proxying to: '#{host}:#{port}'"
            conn.server session, :host => host, :port => port
            
            conn.relay_to_servers buffer
          rescue StandardError => se
            puts ". Error proxying: " + se.to_s
            unbind
            close_connection
          ensure
            buffer.clear
            headers_complete = true
          end
        end
                
        conn.on_data do |data|
          unless headers_complete
            buffer << data
            header_parser << data
          end
          
          data
        end
      end
    end
  end
end
