require 'eventmachine'
require 'http/parser'
require 'uuid'
require 'diplomat'
require 'ipaddr'

module Tubes
  class Proxy

    def self.run(host, port, cidr)
      cidr = IPAddr.new(cidr)

      EventMachine.epoll
      EventMachine.run do
        puts "listening on #{host}:#{port} from #{cidr}"

        trap("TERM") { stop }
        trap("INT")  { stop }

        EventMachine::start_server(host, port, Tubes::ServerConnection, {debug: false}) do |conn|
          buffer = ''
          headers_complete = false

          header_parser = Http::Parser.new
          header_parser.on_headers_complete = proc do |headers|
            session = UUID.generate

            begin
              tubes_host = headers['Host'].split(':').first.split(".").first
              print "#{session}: ( #{headers['Host']} )"
              services = Diplomat::Service.get(tubes_host, scope=:all)
              service = services.select {|s| cidr.include?(s.ServiceAddress) }.sample
              random_service = services.sample
              if (service)
                host = service.ServiceAddress
                port = service.ServicePort

                puts " proxying to: '#{host}:#{port}'"
                conn.server session, :host => host, :port => port, tls: false
                
                conn.relay_to_servers buffer
              elsif random_service
                host = random_service.ServiceAddress
                port = random_service.ServicePort
                puts " proxy to '#{host}:443'"
                conn.server session, :host => "10.220.192.217", :port => "443", tls: {sni_hostname: headers['Host'].split(':').first}
                conn.relay_to_servers buffer
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
                  
          conn.on_data do |data|
            unless headers_complete
              buffer << data
              header_parser << data
              nil
            else
              data
            end
          end
        end
      end
    end

  
    def self.stop
      puts "Terminating ProxyServer"
      EventMachine.stop
    end
    
  end
end
