#!/bin/bash

set -e

echo "PowerDNS-Admin Installation im Docker (ohne PowerDNS, mit Architekturprüfung)"

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
apt update
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=$ARCH] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Sicherstellen, dass Docker aktiviert ist
systemctl start docker
systemctl enable docker

# Überprüfen, ob powerdns_passwords.txt existiert
PASSWORD_FILE="powerdns_passwords.txt"
if [ ! -f "$PASSWORD_FILE" ]; then
  echo "Die Datei $PASSWORD_FILE wurde nicht gefunden! Bitte stelle sicher, dass sie vorhanden ist."
  exit 1
fi

# Variablen aus powerdns_passwords.txt auslesen
DB_NAME="pdns"
DB_USER="pdns_user"
DB_PASSWORD=$(grep "PowerDNS Passwort" "$PASSWORD_FILE" | awk -F': ' '{print $2}')
PDNS_API_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
DOMAIN=""

# Domain anfordern
read -p "Bitte geben Sie die Domain für PowerDNS-Admin ein (z. B. admin.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
  echo "Es wurde keine Domain angegeben. Das Skript wird abgebrochen."
  exit 1
fi

STATS_URL="http://$DOMAIN:8081/"

echo "Verwendete Zugangsdaten:"
echo "PowerDNS-Admin-Datenbank: $DB_NAME"
echo "PowerDNS-Admin-Benutzer: $DB_USER"
echo "PowerDNS-Admin-Passwort: $DB_PASSWORD"
echo "PowerDNS-API-Key: $PDNS_API_KEY"
echo "Stats URL: $STATS_URL"
echo "Domain: $DOMAIN"

# Installationsverzeichnis erstellen
INSTALL_DIR="/opt/pdns_admin_only"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Docker-Compose-Konfiguration erstellen
echo "Docker-Compose-Konfiguration wird erstellt..."
cat <<EOL > docker-compose.yml
version: '3'

services:
  powerdns-admin:
    image: ngoduykhanh/powerdns-admin:latest
    container_name: powerdns-admin
    restart: always
    ports:
      - "9191:80"
    environment:
      - FLASK_ENV=production
      - SECRET_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
      - SQLALCHEMY_DATABASE_URI=mysql+pymysql://$DB_USER:$DB_PASSWORD@127.0.0.1/$DB_NAME
      - PDNS_STATS_URL=$STATS_URL
      - PDNS_API_KEY=$PDNS_API_KEY
      - EXTERNAL_URL=https://$DOMAIN
EOL

# Docker-Compose-Setup starten
echo "Docker-Compose-Setup wird gestartet..."
docker-compose up -d

# Status anzeigen
echo "PowerDNS-Admin Docker-Setup wurde gestartet!"
echo "Besuche: https://$DOMAIN"
