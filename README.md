# PowerDNS 4.9 Installation Scripts

Dieses Repository enthält Skripte zur Installation des **PowerDNS Authoritative Servers 4.9.x** auf **Debian 12 (Bookworm)** und **Ubuntu 24.04 (Lunar)**. Die Skripte automatisieren die Installation und Konfiguration von PowerDNS und MariaDB.

---

## Voraussetzungen
- Root-Zugriff oder ein Benutzer mit `sudo`-Rechten.
- Ein Server mit **Debian 12** oder **Ubuntu 24.04**.
- Internetzugang zum Herunterladen von Paketen.

---

## Enthaltene Dateien

- `install_pdns_debian12.sh`: Automatisches Installationsskript für Debian 12.
- `install_pdns_ubuntu24.sh`: Automatisches Installationsskript für Ubuntu 24.04.

---

## Installation

### 1. Skripte herunterladen
Lade die Skripte herunter oder klone das Repository:
```bash
git clone https://github.com/<username>/<repository>.git
cd <repository>
```

### 2. Skripte ausführbar machen
Mache die Skripte ausführbar:
```bash
chmod +x install_pdns_debian12.sh install_pdns_ubuntu24.sh
```

### 3. Skript ausführen
Führe das entsprechende Skript basierend auf deinem Betriebssystem aus:

#### Für Debian 12:
```bash
sudo ./install_pdns_debian12.sh
```

#### Für Ubuntu 24.04:
```bash
sudo ./install_pdns_ubuntu24.sh
```

---

## Funktionen der Skripte

1. **Systemaktualisierung:**
   - `apt update` und `apt upgrade`, um das System auf den neuesten Stand zu bringen.

2. **PowerDNS-Repository einrichten:**
   - Fügt das passende Repository hinzu:
     - Debian 12: `bookworm-auth-49`
     - Ubuntu 24.04: `noble-auth-49`

3. **Standard-DNS-Dienst deaktivieren:**
   - Stoppt und deaktiviert `systemd-resolved`, um Konflikte zu vermeiden.

4. **PowerDNS und MySQL installieren:**
   - Installiert `pdns-server` und `pdns-backend-mysql`.
   - Installiert MariaDB und sichert die Konfiguration.

5. **Datenbank einrichten:**
   - Erstellt eine MySQL-Datenbank und Benutzer für PowerDNS.
   - Importiert das PowerDNS-Schema in die Datenbank.

6. **PowerDNS konfigurieren:**
   - Konfiguriert `/etc/powerdns/pdns.conf` für die Nutzung des MySQL-Backends.

7. **Dienstverwaltung:**
   - Startet den PowerDNS-Dienst und aktiviert ihn für den automatischen Start.

---

## Überprüfung der Installation

### PowerDNS-Dienststatus überprüfen
Überprüfe, ob der PowerDNS-Dienst korrekt läuft:
```bash
sudo systemctl status pdns
```

### DNS-Server testen
Teste den DNS-Server mit `dig`:
```bash
dig @127.0.0.1 example.com
```

---

## Generierte Dateien

Nach der Ausführung der Skripte wird eine Datei mit den generierten Zugangsdaten erstellt:
- **`powerdns_passwords.txt`**

Diese Datei enthält:
- MySQL Root Passwort
- PowerDNS Datenbankname, Benutzer und Passwort

Beispiel:
```plaintext
MySQL Root Passwort: <generiertes_passwort>
PowerDNS Datenbank: pdns
PowerDNS Benutzer: pdns_user
PowerDNS Passwort: <generiertes_passwort>
```

**Hinweis:** Bewahre diese Datei an einem sicheren Ort auf.

---

## Sicherheitshinweise

- **Firewall-Konfiguration:**
  Öffne die DNS-Ports, falls eine Firewall aktiv ist:
  ```bash
  sudo ufw allow 53/tcp
  sudo ufw allow 53/udp
  ```

- **Datenbank-Sicherheit:**
  Verwende starke Passwörter und sichere die Datenbank mit SSL/TLS.

- **Systemhärtung:**
  Setze zusätzliche Sicherheitsmaßnahmen ein, z. B. Fail2Ban und regelmäßige Updates.

---

## Weitere Informationen

- [PowerDNS Dokumentation](https://doc.powerdns.com)
- [PowerDNS Repository](https://repo.powerdns.com)

--- 

## Lizenz
Dieses Projekt steht unter der [MIT-Lizenz](LICENSE).
