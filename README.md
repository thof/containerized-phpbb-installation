# Containerized phpBB installation

## Goal
The goal of this short project was to prepare a minimal and lightweight installation of phpBB on a tiny VPS 
that already hosts a few services.

## Components
The installation consists of:
* Forum software - [phpBB 3.3.4](https://www.phpbb.com/downloads/3.3/install)
* Database - [SQLite](https://www.sqlite.org/index.html)
* Web server - [nginx:latest](https://hub.docker.com/_/nginx) container image
* PHP-FPM - [php:7.4-fpm-alpine](https://hub.docker.com/_/php) container image
* TLS/SSL certificates - [acme.sh](https://hub.docker.com/r/neilpang/acme.sh) container image
* Container runtime - [podman](https://podman.io/) (like Docker but daemonless hence uses less resources)
* Running multi-container applications - [podman-compose](https://github.com/containers/podman-compose)

## Setup

### Prerequisites
* Linux server
* Podman and Podman Compose installed

In my case it's Ubuntu 20.10:
1. Install the latest version of Podman from Kubic repo as described 
[here](https://podman.io/getting-started/installation#ubuntu).
2. Install Podman Compose using [pip3](https://github.com/containers/podman-compose#installation): 
```shell
pip3 install podman-compose
```

### Installation steps

1. Clone this Git repository.
2. The working directory is `forum`:
```shell
cd forum
```
3. Get the latest [phpBB](https://www.phpbb.com/downloads/) and extract all files under the `web` directory.
4. Review the nginx configuration file `default.conf`. It's already adjusted to handle phpBB properly. At minimum 
replace all occurrences of `example.com`.
5. Review the `docker-compose.yaml` file which contains the definition for two services (stack):
    1. `web` - nginx web server exposing two ports (80, 443) and three volumes:
       1. `/certs` - TLS/SSL certificates created by `acme.sh`
       2. `/web` - phpBB files
       3. `/etc/nginx/conf.d/default.conf` - nginx configuration file mentioned earlier
    2. `php` - PHP-FPM with two volumes:
       1. `/web` - phpBB files
       2. `/usr/local/etc/php/php.ini` - to ensure compatibility it may be a good idea to extract the
       `php.ini-production` file directly from the PHP container image. It can be found under `/usr/local/etc/php/`.
6. Create and start the entire stack defined in `docker-compose.yaml`:
```shell
podman-compose up --detach
```
8. Ensure that both services started correctly: `podman ps`:
```txt
CONTAINER ID  IMAGE                                 COMMAND               CREATED       STATUS           PORTS                                     NAMES
8d5590cfb0d9  docker.io/library/php:7.4-fpm-alpine  php-fpm               4 months ago  Up 4 months ago  0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp  forum_php_1
b7084cead846  docker.io/library/nginx:latest        nginx -g daemon o...  4 months ago  Up 4 months ago  0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp  forum_web_1
```
9. Issue a new TLS/SSL certificate using the `acme.sh` container image (replace `example.com` in the command below):
```shell
podman run -it -v $(pwd)/acme_cert:/acme.sh -v $(pwd)/web:/web neilpang/acme.sh --register-account -m contact@example.com --issue -d example.com -d www.example.com -w /web
```
10. Verify that certificates have been created correctly by checking the directory `acme_cert/example.com/`.
11. Once the certificates are correctly issued, we need to install them under the `cert/` directory, 
i.e. prepare for nginx (replace `example.com` again):
```shell
podman run -it -v $(pwd)/acme_cert:/acme.sh -v $(pwd)/web:/web -v $(pwd)/certs:/certs neilpang/acme.sh --install-cert -d example.com -d www.example.com --key-file /certs/key.pem --fullchain-file /certs/cert.pem
```
12. Verify that the `cert/` directory contains the key and certificate:
```shell
$ ls certs/
cert.pem  key.pem
```
13. Restart the entire stack to let nginx consume the new certificates: 
```shell
podman-compose down && podman-compose up --detach
```
14. Verify that the website returns a valid certificate, i.e. open the URL in a web browser. 

### Automated certificate renewal

The script `renew_cert.sh` can be used to periodically renew the certificate and reload nginx instance.
The most well-known job scheduler is obviously a cron, but systemd timers offer more and are easier to monitor.
1. Make `renew_cert.sh` executable:
```shell
chmod +x renew_cert.sh
```
2. Copy files from `cert-renewal-timer` (root of this repo) to `/etc/systemd/system/`:
```shell
cp cert-renewal-timer/* /etc/systemd/system/
```
3. Edit `/etc/systemd/system/renew-cert.service` by updating `WorkingDirectory` and `ExecStart` to point to 
the location of `renew_cert.sh`.
4. Enable the timer:
```shell
systemctl enable renew-cert.timer
```
5. Every Monday it will try to renew the certificate if needed. Just look at `systemctl status renew-cert` for status.

### Post-installation steps

1. The first step is to run the `set_phpbb_perm.sh` script to set the required permissions in the `web` directory. 
2. Start the phpBB installation as usual using the web wizard. 
3. The only specific step is related to database setup, since we want to use SQLite. Fortunately the support for 
SQLite is already built-in to the PHP-FPM container image, so we don't need any additional component. It's enough to 
refer to the DB file `/web/sqlitedb/forum.db` and leave other fields blank.
