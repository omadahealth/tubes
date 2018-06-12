require 'eventmachine'

module Tubes
  class BackendConnection < EventMachine::Connection
    attr_accessor :plexer, :name, :debug

    def initialize(debug = false, tls=false)

      @cert_store = OpenSSL::X509::Store.new
      @cert_store.set_default_paths

      @server_cert = []

      @debug = debug
      @tls = tls
      @connected = EM::DefaultDeferrable.new
    end

    def post_init
      if @tls
        start_tls :verify_peer => true, :sni_hostname => @tls[:sni_hostname]
      end
    end

    def ssl_handshake_completed
      debug [@name, :ssl_handshake_completed]

      cert_to_check = @server_cert.reverse.inject("") do |v, cert|
        v += cert
      end
      certificate = OpenSSL::X509::Certificate.new(cert_to_check)

      unless OpenSSL::SSL.verify_certificate_identity(certificate, @tls[:sni_hostname])
        close_connection
      end
    end

    def ssl_verify_peer(cert)
      debug [@name, :ssl_verify_peer, @tls[:sni_hostname]]
      @server_cert << cert

      cert_to_check = @server_cert.inject("") { |v, cert| v += cert }
      
      certificate = OpenSSL::X509::Certificate.new(cert_to_check)
      @cert_store.verify(certificate)
    end


    def connection_completed
      debug [@name, :conn_complete]
      @plexer.connected(@name)
      @connected.succeed
    end

    def receive_data(data)
      debug [@name, data]
      @plexer.relay_from_backend(@name, data)
    end

    # Buffer data until the connection to the backend server
    # is established and is ready for use
    def send(data)
      @connected.callback { send_data data }
    end

    # Notify upstream plexer that the backend server is done
    # processing the request
    def unbind(reason = nil)
      debug [@name, :unbind, reason]
      @plexer.unbind_backend(@name)
    end

    private

    def debug(*data)
      return unless @debug
      require 'pp'
      pp data
      puts
    end
  end
end