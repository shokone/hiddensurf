#!/usr/bin/env bash

## Script to install HiddenSurf
# 
#
# Author: 
# Version: 1.1
# 

set -o errexit

GREEN='\033[1;92m'
RED='\033[1;91m'
RESETCOLOR='\033[1;00m'
DATE="$(date '+%Y%m%d%H%M')"

[ "$(id -u)" -ne 0 ] && echo -e "[${RED}ERROR${RESETCOLOR}] This script must run as root." && exit 1

echo -e "[INFO] This script will install HiddenSurf on your computer..."

echo "[INFO] Installing packages..."
apt-get install tor macchanger resolvconf dnsmasq privoxy tor-arm libnotify-bin curl bleachbit i2pd jq nyx
echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Packages installed."


# backup original config files
echo "[INFO] Backing up files..."
[ -f "/etc/privoxy/config" ] && cp -f "/etc/privoxy/config" "/etc/privoxy/config.${DATE}"
[ -f "/etc/tor/torrc" ] && cp -f "/etc/tor/torrc" "/etc/tor/torrc.${DATE}"
[ -f "/etc/default/hiddensurf.conf" ] && cp -f "/etc/default/hiddensurf.conf" "/etc/default/hiddensurf.conf.${DATE}"
echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Backups completed."


# copy custom config files
echo "[INFO] Copying config files..."
[ -d "/tmp/hiddensurf" ] && repopath="/tmp/hiddensurf/" || repopath=""
cp -f "${repopath}conf/hiddensurf.conf" "/etc/default/hiddensurf.conf"
cp -f "${repopath}hiddensurf.sh" "/etc/init.d/hiddensurf.sh"
cp -f "${repopath}hiddensurf" "/usr/bin/hiddensurf"
cp -f "${repopath}conf/privoxy.conf" "/etc/privoxy/config"
cp -f "${repopath}conf/torrc" "/etc/tor/torrc"
echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Config files copied."


# and apply permissions to needed files
echo "[INFO] Changing permissions..."
chmod 0755 /etc/init.d/hiddensurf.sh /usr/bin/hiddensurf 
chmod 0644 /etc/default/hiddensurf.conf
echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Permissions changed."


echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Install complete!"
echo "[INFO] Now you can surf the Internet anonymously."
echo "[INFO] To start use this command"
echo "sudo hiddensurf help"

exit 0
