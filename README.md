# OSTicket

Deploy OSTicket using Docker, Docker-Compose or Hashicorp Nomad.


* [Provision OSticket with Docker](https://mpolinowski.github.io/docs/DevOps/Provisioning/2022-10-16--os-ticket-docker/2022-10-16)
* [Hashicorp Nomad to set up an OSTicket Helpdesk - Part I](https://mpolinowski.github.io/docs/DevOps/Hashicorp/2022-10-21-hashicorp-nomad-for-osticket-part-i/2022-10-21)
* [Hashicorp Nomad to set up an OSTicket Helpdesk - Part II](https://mpolinowski.github.io/docs/DevOps/Hashicorp/2022-10-25-hashicorp-nomad-for-osticket-part-ii/2022-10-25)
* [OSticket REST API Calls](https://mpolinowski.github.io/docs/DevOps/Provisioning/2022-10-27--os-ticket-rest-api/2022-10-27)


## Docker

[OSTicket recommends](https://docs.osticket.com/en/latest/Getting%20Started/Installation.html) to use the official Docker Image from [hub.docker.com](https://hub.docker.com/r/osticket/osticket/):


```bash
docker pull osticket/osticket:latest
docker pull mariadb:latest
docker run --name osticket_mysql -d -e MYSQL_ROOT_PASSWORD=secret \
-e MYSQL_USER=osticket -e MYSQL_PASSWORD=secret -e MYSQL_DATABASE=osticket mariadb:latest
docker run --name osticket -d --link osticket_mysql:mysql -p 8080:80 osticket/osticket
```


## Docker-Compose

Both tasks - frontend and SQL backend - can be combined in a single `docker-compose.yml` file:


```yml
version: '3.8'
services:

  osticket-app:
    image: osticket/osticket:latest
    container_name: osticket
    volumes:
      - type: bind
        source: ./src/include/i18n/de.phar
        target: /var/www/src/public/include/i18n/de.phar
        read_only: true
    environment:
      - CONTAINER_NAME=osticket
      - MYSQL_USER=osticket
      - MYSQL_HOST=osticket-db
      - MYSQL_PASSWORD=secret
      - MYSQL_DATABASE=osticket
    ports:
      - 8080:80
    depends_on:
      - osticket-db
    networks:
      - services
    links:
      - osticket-db
    restart: unless-stopped

  osticket-db:
    image: mariadb:latest
    container_name: osticket-db
    volumes:
      - /opt/osticket/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=secret
      - MYSQL_USER=osticket
      - MYSQL_PASSWORD=secret
      - MYSQL_DATABASE=osticket
      - CONTAINER_NAME=osticket-db
    networks:
      - services
    restart: unless-stopped

networks:
  services:
    external: false
```


## Hashicorp Nomad & Consul


```bash
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
                image = "my.gitlab.com:12345/osticket-docker:latest"
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
```
