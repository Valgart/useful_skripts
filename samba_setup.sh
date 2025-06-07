#!/bin/bash

# Sicherstellen, dass das Skript mit Root-Rechten läuft
if [[ $EUID -ne 0 ]]; then
  echo "Bitte mit sudo oder als root ausführen."
  exit 1
fi

# System aktualisieren
apt update
apt upgrade -y

# Username direkt vom Terminal einlesen
read -p "Gib den neuen Benutzernamen ein: " USERNAME < /dev/tty

# User anlegen und Passwort setzen
useradd -m "$USERNAME"
if [[ $? -ne 0 ]]; then
  echo "Fehler beim Anlegen des Benutzers."
  exit 1
fi

echo "Setze Passwort für $USERNAME:"
passwd "$USERNAME" < /dev/tty

# Verzeichnisse anlegen und Berechtigungen setzen
mkdir -p /shares/Daten
chmod 777 /shares/Daten

# Samba installieren
apt install samba samba-common-bin -y

# Samba-Konfiguration anpassen
SMB_CONF="/etc/samba/smb.conf"

# server signing in [global] einfügen (falls nicht bereits vorhanden)
grep -q "^ *server signing" "$SMB_CONF" || sed -i '/\[global\]/a \
    server signing = auto\
    server signing = mandatory' "$SMB_CONF"

# Share-Definition ans Ende anhängen (wenn noch nicht vorhanden)
if ! grep -q "^\[Daten\]" "$SMB_CONF"; then
  cat <<EOF >> "$SMB_CONF"

[Daten]
   path = /shares/Daten
   writeable = Yes
   create mask = 0777
   directory mask = 0777
   public = yes
EOF
fi

# Samba-Passwort für den neuen User setzen
echo "Lege Samba-Passwort für $USERNAME an:"
smbpasswd -a "$USERNAME" < /dev/tty

echo "Fertig! Der Benutzer $USERNAME wurde angelegt und Samba ist konfiguriert."
