require 'em-proxy'
require 'http/parser'
require 'uuid'

module Tubes
  class Proxy
    attr_accessor :host, :port

    def initialize(host, port, target_domain, resolv_opts = {})
      @host = host
      @port = port
      @target_domain = target_domain
      @resolv_opts = resolv_opts
    end


    def run
      puts "listening on #{host}:#{port}..."
      resolver = Resolv::DNS.new(@resolv_opts)
      target_domain = @target_domain

      ::Proxy.start(:host => host, :port => port) do |conn|
        @buffer = ''
        @headers_complete = false

        @p = Http::Parser.new
        @p.on_headers_complete = proc do |headers|
          begin
            session = UUID.generate
            tubes_host = headers['Host'].split(':').first.split(".").first
            puts "New session: #{session} ( #{tubes_host}#{@p.request_url} )"
            puts "Attempting to get SRV record for '#{tubes_host}.#{target_domain}'"
            record = resolver.getresources("#{tubes_host}.#{target_domain}", Resolv::DNS::Resource::IN::SRV).sample
            host = record.target
            port = record.port

            host = resolver.getaddress(host) if host.is_a? Resolv::DNS::Name
            puts "Proxying to: '#{host}:#{port}'"
            conn.server session, :host => host, :port => port
            
            conn.relay_to_servers @buffer
          rescue StandardError => se
            print "Error proxying: " + se
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
