#!/bin/bash

# Sicherstellen, dass das Skript mit Root-Rechten läuft
if [[ $EUID -ne 0 ]]; then
  echo "Bitte mit sudo oder als root ausführen."
  exit 1
fi

# Erwartet den Usernamen als ersten Parameter
if [[ -z "$1" ]]; then
  echo "Usage: $0 <username>"
  exit 1
fi
USERNAME="$1"

# System aktualisieren
apt update
apt upgrade -y

# User anlegen
useradd -m "$USERNAME"
if [[ $? -ne 0 ]]; then
  echo "Fehler beim Anlegen des Benutzers."
  exit 1
fi

# Passwort für den neuen User interaktiv setzen (mit Wiederholung bei Tippfehler)
while true; do
  echo "Setze Passwort für $USERNAME:"
  passwd "$USERNAME" < /dev/tty
  if [[ $? -eq 0 ]]; then
    break
  else
    echo "Passwörter stimmen nicht überein. Bitte erneut versuchen."
  fi
done

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

# Samba-Passwort für den neuen User interaktiv setzen (mit Wiederholung bei Tippfehler)
while true; do
  echo "Lege Samba-Passwort für $USERNAME an:"
  smbpasswd -a "$USERNAME" < /dev/tty
  if [[ $? -eq 0 ]]; then
    break
  else
    echo "Passwörter stimmen nicht überein. Bitte erneut versuchen."
  fi
done

# Zeitzone auf Europe/Berlin setzen
echo "Europe/Berlin" > /etc/timezone
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata

# IP-Adresse anzeigen
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "Die primäre IP-Adresse dieses Servers ist: $IP_ADDR"

echo "Fertig! Der Benutzer $USERNAME wurde angelegt, Samba konfiguriert, Zeitzone gesetzt und IP angezeigt."
