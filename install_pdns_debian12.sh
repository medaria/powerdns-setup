#!/bin/bash

set -e

echo "PowerDNS Installation auf Debian 12"

# Überprüfen auf Root-Rechte
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript als Root oder mit sudo aus."
  exit 1
fi

# Variablen
DB_NAME="pdns"
DB_USER="pdns_user"
DB_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
PDNS_API_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
ROOT_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)

echo "Generierte Zugangsdaten:"
echo "Datenbank-Benutzer: $DB_USER"
echo "Datenbank-Passwort: $DB_PASSWORD"
echo "MySQL Root-Passwort: $ROOT_PASSWORD"
echo "PDNS API Key: $PDNS_API_KEY"

# Repository hinzufügen
echo "Füge PowerDNS-Repository hinzu..."
cat <<EOL > /etc/apt/sources.list.d/pdns.list
deb [signed-by=/etc/apt/keyrings/auth-49-pub.asc] http://repo.powerdns.com/debian bookworm-auth-49 main
EOL

# Priorität setzen
cat <<EOL > /etc/apt/preferences.d/auth-49
Package: auth*
Pin: origin repo.powerdns.com
Pin-Priority: 600
EOL

# GPG-Schlüssel hinzufügen
echo "Installiere GPG-Schlüssel..."
install -d /etc/apt/keyrings
curl https://repo.powerdns.com/FD380FBB-pub.asc | tee /etc/apt/keyrings/auth-49-pub.asc > /dev/null

# Pakete aktualisieren und installieren
echo "Installiere PowerDNS-Server..."
apt update
apt install -y pdns-server pdns-backend-mysql mariadb-server

# MySQL/MariaDB konfigurieren
echo "Setze Root-Passwort für MySQL/MariaDB..."
mysqladmin -u root password "$ROOT_PASSWORD"

echo "Richte MySQL-Datenbank ein..."
mysql -u root -p"$ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# PowerDNS mit MySQL konfigurieren
echo "Konfiguriere PowerDNS mit MySQL..."
cat <<EOL > /etc/powerdns/pdns.conf
launch=gmysql
gmysql-host=localhost
gmysql-dbname=$DB_NAME
gmysql-user=$DB_USER
gmysql-password=$DB_PASSWORD
api=yes
api-key=$PDNS_API_KEY
webserver=yes
webserver-address=0.0.0.0
webserver-port=8081
EOL

# DNS-Standarddienste deaktivieren
echo "Deaktivieren der Standard-DNS-Funktionalität..."

if systemctl is-active --quiet systemd-resolved.service; then
  echo "Stopping and disabling systemd-resolved..."
  systemctl stop systemd-resolved.service
  systemctl disable systemd-resolved.service
  rm -f /etc/resolv.conf
  echo "nameserver 127.0.0.1" > /etc/resolv.conf
else
  echo "systemd-resolved ist nicht aktiv. Keine weiteren Aktionen erforderlich."
fi

# PowerDNS starten und aktivieren
echo "Starte PowerDNS-Server..."
systemctl restart pdns
systemctl enable pdns

# Status prüfen
echo "Prüfe PowerDNS-Server..."
systemctl status pdns --no-pager

echo "PowerDNS-Installation abgeschlossen!"
echo "Webserver ist unter http://<server-ip>:8081 erreichbar."
echo "API-Key: $PDNS_API_KEY"
