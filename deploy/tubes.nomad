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
          tubes = 3000
        }
        logging {
          type = "journald"
        }

      }
      
      resources {
        cpu = 500
        memory = 128
        network {
          mbits = 1
          port "http" {
            static = 3000
          }
        }
      }
      service {
        name = "tubes"
        port = "http"
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

