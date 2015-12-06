require 'em-proxy'
require 'http/parser'
require 'uuid'
require 'docker'

module Tubes
  class Proxy
    attr_accessor :host, :port

    def initialize(host, port)
      @host = host
      @port = port
    end


    def run
      puts "listening on #{host}:#{port}..."

      ::Proxy.start(:host => host, :port => port) do |conn|
        @buffer = ''
        @headers_complete = false

        @p = Http::Parser.new
        @p.on_headers_complete = proc do |headers|
          begin
            session = UUID.generate
            tubes_host = headers['Host'].split(':').first.split(".").first
            puts "New session: #{session} ( #{tubes_host}#{@p.request_url} )"
            target_container = Docker::Container.all(filters: {
                                                       label: ["tubes.http.port",
                                                               "tubes.http.host=#{tubes_host}"]
                                                     }.to_json).sample
            
            port = target_container.info["Labels"]["tubes.http.port"]
            host = Docker::Container.get(target_container.id).info["NetworkSettings"]["IPAddress"]
            conn.server session, :host => host, :port => port
            
            conn.relay_to_servers @buffer
          rescue
            puts "Error processing request"
            conn.close_connection
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
