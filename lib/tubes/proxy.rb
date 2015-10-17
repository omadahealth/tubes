require 'celluloid/current'
require 'celluloid/io'
require 'celluloid/debug'

module Tubes
  class Proxy
    include Celluloid::IO
    include Celluloid::Internals::Logger

    finalizer :shutdown

    def initialize(host, port)
      @server = Celluloid::IO::TCPServer.new(host, port)
    end

    def shutdown
      @server.close if @server
    end

    def run
      loop {
        info "*** Starting proxy server"
        socket = @server.accept
        proxy_socket = Celluloid::IO::TCPSocket.new 'localhost', 80
        
        info "Got a socket: #{socket.object_id}"
        info "connected to: #{proxy_socket.object_id}"

        handle_connection socket, proxy_socket
      }
    end

    def handle_connection(socket, proxy_socket)
      async.proxy_socket(proxy_socket,socket, 1)
      async.proxy_socket(socket, proxy_socket, 2)
    end

    def close_socket(s)
      info "#{s.object_id} closing"

      s.close
    rescue Exception => e
      info "#{s.object_id} raise error when closing: #{e.inspect}"
    end

    def proxy_socket(socket_from, socket_to, n)
      info "#{n}: Proxying #{socket_from.object_id} to #{socket_to.object_id}"

      begin
        buf = ''
        loop do
          socket_to.write socket_from.readpartial(4096, buf) 
        end
      rescue Exception => e
        close_socket socket_to
        close_socket socket_from
      end
    ensure
      info "#{n}: Finished #{socket_from.object_id} to #{socket_to.object_id}"
    end
  end
end
