job "tubes/{{ datacenter }}" {
  datacenters = ["{{ datacenter }}"]

  type = "system"

  update {
    stagger = "5s"
    max_parallel = 1
  }

  group "routing" {
    task "tubes" {
      driver = "docker"
      config {
        image = "{{ 'TUBES_IMAGE' | env }}:{{ version }}"
        args = ["--consul", "{{ 'CONSUL_URL' | env }}", "-p", "3000","--match-cidr", "${attr.unique.network.ip-address}/32"]
        port_map {
          proxy = 3000
          metrics = 3001
        }
        logging {
          type = "journald"
        }

      }
      
      resources {
        cpu = 500
        memory = 64
        network {
          mbits = 1
          port "proxy" {
            static = 3000
          }
          port "metrics" {
            static = 3002
          }
        }
      }
      service {
        name = "tubes-proxy"
        port = "proxy"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "20s"
        }
      }
      service {
        name = "tubes-metrics"
        port = "metrics"
        tags = ["prometheus-metrics"]
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "20s"
        }
      }
    }
  }
}

