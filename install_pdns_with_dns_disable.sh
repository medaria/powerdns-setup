#!/bin/bash

set -e

echo "PowerDNS Installation Script for Ubuntu 24.04 with 48-Character Passwords"

# Überprüfen, ob das Skript mit Root-Rechten ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie das Skript als Root oder mit sudo aus."
  exit 1
fi

# Generieren von Passwörtern mit 48 Zeichen Länge
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
PDNS_DB="pdns"
PDNS_USER="pdns_user"
PDNS_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)

echo "Generierte Passwörter:"
echo "MySQL Root Passwort: $MYSQL_ROOT_PASSWORD"
echo "PowerDNS Datenbank Passwort: $PDNS_PASSWORD"

# Speichern der Passwörter in einer Datei zur späteren Referenz
PASSWORD_FILE="powerdns_passwords.txt"
cat <<EOL > $PASSWORD_FILE
MySQL Root Passwort: $MYSQL_ROOT_PASSWORD
PowerDNS Datenbank: $PDNS_DB
PowerDNS Benutzer: $PDNS_USER
PowerDNS Passwort: $PDNS_PASSWORD
EOL

echo "Passwörter wurden in $PASSWORD_FILE gespeichert. Bitte bewahren Sie diese Datei sicher auf!"

# Systemaktualisierung
echo "System wird aktualisiert..."
apt update && apt upgrade -y

# Installation notwendiger Abhängigkeiten
echo "Notwendige Abhängigkeiten werden installiert..."
apt install -y wget curl gnupg lsb-release

# Deaktivieren der Standard-DNS-Funktionalität
echo "Deaktivieren der Standard-DNS-Funktionalität..."
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Repository und Präferenzen konfigurieren
echo "PowerDNS-Repository wird hinzugefügt..."
install -d /etc/apt/keyrings
curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo tee /etc/apt/keyrings/auth-49-pub.asc
echo "deb [signed-by=/etc/apt/keyrings/auth-49-pub.asc] http://repo.powerdns.com/ubuntu noble-auth-49 main" > /etc/apt/sources.list.d/pdns.list
echo "Package: auth*
Pin: origin repo.powerdns.com
Pin-Priority: 600" > /etc/apt/preferences.d/auth-49

# Paketliste aktualisieren und PowerDNS installieren
echo "Paketliste wird aktualisiert und PowerDNS wird installiert..."
apt update
apt install -y pdns-server pdns-backend-mysql

# MariaDB installieren und konfigurieren
echo "MariaDB wird installiert..."
apt install -y mariadb-server mariadb-client

echo "MariaDB wird konfiguriert..."
mysql_secure_installation <<EOF

y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
y
y
y
y
EOF

# Datenbank und Benutzer für PowerDNS erstellen
echo "PowerDNS-Datenbank und Benutzer werden erstellt..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
CREATE DATABASE $PDNS_DB;
CREATE USER '$PDNS_USER'@'localhost' IDENTIFIED BY '$PDNS_PASSWORD';
GRANT ALL PRIVILEGES ON $PDNS_DB.* TO '$PDNS_USER'@'localhost';
FLUSH PRIVILEGES;"

# PowerDNS-Schema importieren
echo "Schema für PowerDNS wird importiert..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" $PDNS_DB < /usr/share/doc/pdns-backend-mysql/schema.mysql.sql

# PowerDNS konfigurieren
echo "PowerDNS wird konfiguriert..."
PDNS_CONFIG="/etc/powerdns/pdns.conf"

cat <<EOL > $PDNS_CONFIG
launch=gmysql
gmysql-host=127.0.0.1
gmysql-user=$PDNS_USER
gmysql-password=$PDNS_PASSWORD
gmysql-dbname=$PDNS_DB
EOL

# Neustart und Aktivierung des PowerDNS-Dienstes
echo "PowerDNS-Dienst wird neu gestartet und aktiviert..."
systemctl restart pdns
systemctl enable pdns

echo "PowerDNS-Installation und -Konfiguration abgeschlossen!"
echo "Passwörter wurden in $PASSWORD_FILE gespeichert."
