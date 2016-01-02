require 'em-proxy'
require 'http/parser'
require 'uuid'
require 'diplomat'

module Tubes
  class Proxy
    attr_accessor :host, :port

    def initialize(host, port)
      @host = host
      @port = port
    end


    def run
      puts "listening on #{host}:#{port}..."
      resolver = Resolv::DNS.new(@resolv_opts)

      ::Proxy.start(:host => host, :port => port) do |conn|
        @buffer = ''
        @headers_complete = false

        @p = Http::Parser.new
        @p.on_headers_complete = proc do |headers|
          begin
            session = UUID.generate
            tubes_host = headers['Host'].split(':').first.split(".").first
            print "New session: #{session} ( #{@p.request_url} )"
            service = Diplomat::Service.get(tubes_host, scope=:all).sample
            host = service.Address
            port = service.ServicePort

            puts " proxying to: '#{host}:#{port}'"
            conn.server session, :host => host, :port => port
            
            conn.relay_to_servers @buffer
          rescue StandardError => se
            puts "Error proxying: " + se.to_s
          ensure
            @buffer.clear
            @headers_complete = true
          end
        end
                
        conn.on_data do |data|
          unless @headers_complete
            @buffer << data
            @p << data
          end
          
          data
        end
      end
    end
  end
end
