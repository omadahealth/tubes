require 'celluloid'
require 'celluloid/io'
#require 'celluloid/autostart'
require 'celluloid/debug'


module Tubes
  class Proxy
    include Celluloid::IO
    finalizer :shutdown

    def initialize(host, port)
      puts "*** Starting proxy server on #{host}:#{port}"

      @server = Celluloid::IO::TCPServer.new(host, port)
    end

    def shutdown
      @server.close if @server
    end

    def run
      loop {
        puts "Waiting for accept..."
        socket = @server.accept
        puts "Got a socket"
        async.handle_connection socket
      }
    end

    def handle_connection(socket)
      proxy_socket = TCPSocket.new 'localhost', 80
      async.proxy_socket(proxy_socket,socket)
      proxy_socket(socket, proxy_socket)
    end

    def proxy_socket(socket_from, socket_to)

      loop do
        socket_from.write socket_to.readpartial(4096) 
      end
    rescue EOFError
      socket_from.close
      socket_to.close
    end
  end
end
