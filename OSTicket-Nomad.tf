job "osticket" {
  datacenters = ["mydatacenter"]
    group "osticket" {
        
        network {
            mode = "host"
            port "tcp" {
                static = 3306
            }
            port "http" {
                static = 8080
            }
        }

        update {
            max_parallel = 1
            min_healthy_time  = "10s"
            healthy_deadline  = "5m"
            progress_deadline = "10m"
            auto_revert = true
            auto_promote = true
            canary = 1
        }

        volume "osticket_db" {
            type      = "host"
            read_only = false
            source    = "osticket_db"
        }

        restart {
            attempts = 10
            interval = "5m"
            delay    = "25s"
            mode     = "delay"
        }

        service {
            name = "osticket-db"
            port = "tcp"
            tags = [
                "database"
            ]

            check {
                name     = "DB Health"
                port     = "tcp"
                type     = "tcp"
                interval = "30s"
                timeout  = "4s"
            }
        }

        service {
            name = "osticket-frontend"
            port = "http"
            tags = [
                "frontend"
            ]

            check {
                name     = "HTTP Health"
                path     = "/"
                type     = "http"
                protocol = "http"
                interval = "10s"
                timeout  = "2s"
            }
        }

        task "osticket-db" {
            driver = "docker"

            config {
                image = "mariadb:latest"
                ports = ["tcp"]
                network_mode = "host"
                force_pull = false
            }

            volume_mount {
                volume      = "osticket_db"
                destination = "/var/lib/mysql" #<-- in the container
                read_only   = false
            }

            env {
                MYSQL_ROOT_PASSWORD = "secret"
                MYSQL_USER = "osticket"
                MYSQL_PASSWORD = "secret"
                MYSQL_DATABASE = "osticket"
                CONTAINER_NAME = "127.0.0.1"
            }
        }

        task "osticket-frontend" {
            driver = "docker"

            config {
                image = "my.gitlab.com:12345/server_management/osticket-docker:latest"
                ports = ["http"]
                network_mode = "host"
                force_pull = false

                auth {
                    username = "mygitlabuser"
                    password = "asecretpassword"
                }
            }

            env {
                MYSQL_USER = "osticket"
                MYSQL_HOST = "127.0.0.1"
                MYSQL_PASSWORD = "secret"
                MYSQL_DATABASE = "osticket"
            }
        }
    }
} 
