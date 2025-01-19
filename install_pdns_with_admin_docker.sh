#!/bin/bash

# install_pdns_with_admin_docker.sh

set -e

echo "PowerDNS und PowerDNS-Admin Installation im Docker (Master/Slave Setup mit vereinfachter Docker-Installation)"

# Überprüfen auf Root-Rechte
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript als Root oder mit sudo aus."
  exit 1
fi

# Erkennen der Systemarchitektur
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" == "amd64" ]; then
  DOCKER_ARCH="x86_64"
elif [ "$ARCH" == "arm64" ]; then
  DOCKER_ARCH="arm64"
else
  echo "Nicht unterstützte Architektur: $ARCH"
  exit 1
fi

echo "Erkannte Architektur: $DOCKER_ARCH"

# Docker und Docker Compose installieren
echo "Installiere Docker und Docker Compose..."
curl -sSL https://get.docker.com/ | CHANNEL=stable bash && systemctl enable --now docker

# Sicherstellen, dass Docker Compose verfügbar ist
if ! docker compose version &>/dev/null; then
  echo "Docker Compose Plugin konnte nicht gefunden werden. Versuche Legacy-Compose zu installieren..."
  curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true
fi

# Überprüfen, ob Docker Compose erfolgreich installiert wurde
if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
  echo "Docker Compose konnte nicht installiert werden. Bitte überprüfen Sie die Installation."
  exit 1
fi

# Variablen
INSTALL_DIR="/opt/pdns_with_admin"
DB_NAME="pdns"
DB_USER="pdns_user"
DB_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
PDNS_API_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
DOMAIN=""
SETUP_TYPE=""
MASTER_IPS=""

# Setup-Typ anfordern
while [[ "$SETUP_TYPE" != "master" && "$SETUP_TYPE" != "slave" ]]; do
  read -p "Möchten Sie ein Master- oder Slave-Setup einrichten? (master/slave): " SETUP_TYPE
done

if [ "$SETUP_TYPE" == "slave" ]; then
  read -p "Bitte geben Sie die Master-IP(s) ein (z. B. 192.168.1.10,192.168.1.11): " MASTER_IPS
  if [ -z "$MASTER_IPS" ]; then
    echo "Keine Master-IP(s) angegeben. Das Skript wird abgebrochen."
    exit 1
  fi
fi

# Domain anfordern
read -p "Bitte geben Sie die Domain für PowerDNS-Admin ein (z. B. admin.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
  echo "Es wurde keine Domain angegeben. Das Skript wird abgebrochen."
  exit 1
fi

STATS_URL="http://$DOMAIN:8081/"

echo "Generierte Zugangsdaten:"
echo "Datenbank-Benutzer: $DB_USER"
echo "Datenbank-Passwort: $DB_PASSWORD"
echo "PDNS API Key: $PDNS_API_KEY"
echo "Setup-Typ: $SETUP_TYPE"
if [ "$SETUP_TYPE" == "slave" ]; then
  echo "Master-IP(s): $MASTER_IPS"
fi
echo "Domain: $DOMAIN"
echo "Stats URL: $STATS_URL"

# Erstelle das Installationsverzeichnis
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Docker-Compose-Konfiguration erstellen
echo "Docker-Compose-Konfiguration wird erstellt..."
cat <<EOL > docker-compose.yml
version: '3'

services:
  powerdns:
    image: powerdns/pdns:latest
    container_name: powerdns
    restart: always
    environment:
      - PDNS_gmysql-host=db
      - PDNS_gmysql-user=$DB_USER
      - PDNS_gmysql-password=$DB_PASSWORD
      - PDNS_gmysql-dbname=$DB_NAME
      - PDNS_api=yes
      - PDNS_api-key=$PDNS_API_KEY
      - PDNS_webserver=yes
      - PDNS_webserver-address=0.0.0.0
      - PDNS_webserver-port=8081
EOL

if [ "$SETUP_TYPE" == "master" ]; then
  cat <<EOL >> docker-compose.yml
      - PDNS_slave=no
EOL
elif [ "$SETUP_TYPE" == "slave" ]; then
  cat <<EOL >> docker-compose.yml
      - PDNS_slave=yes
      - PDNS_master=$MASTER_IPS
EOL
fi

cat <<EOL >> docker-compose.yml
    ports:
      - "53:53/udp"
      - "53:53/tcp"
      - "8081:8081"
    depends_on:
      - db

  powerdns-admin:
    image: ngoduykhanh/powerdns-admin:latest
    container_name: powerdns-admin
    restart: always
    ports:
      - "9191:80"
    environment:
      - FLASK_ENV=production
      - SECRET_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
      - SQLALCHEMY_DATABASE_URI=mysql+pymysql://$DB_USER:$DB_PASSWORD@db/$DB_NAME
      - PDNS_STATS_URL=$STATS_URL
      - PDNS_API_KEY=$PDNS_API_KEY
      - EXTERNAL_URL=https://$DOMAIN
    depends_on:
      - powerdns
      - db

  db:
    image: mariadb:10.5
    container_name: powerdns-db
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASSWORD
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASSWORD
    volumes:
      - db_data:/var/lib/mysql
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --default-authentication-plugin=mysql_native_password

volumes:
  db_data:
EOL

# Docker-Compose-Setup starten
echo "Docker-Compose-Setup wird gestartet..."
docker compose up -d || docker-compose up -d

# Status anzeigen
echo "PowerDNS und PowerDNS-Admin Docker-Setup wurde gestartet!"
echo "Zugangsdaten:"
echo "Datenbank-Benutzer: $DB_USER"
echo "Datenbank-Passwort: $DB_PASSWORD"
echo "PDNS API Key: $PDNS_API_KEY"
echo "Setup-Typ: $SETUP_TYPE"
if [ "$SETUP_TYPE" == "slave" ]; then
  echo "Master-IP(s): $MASTER_IPS"
fi
echo "Besuche: https://$DOMAIN"
