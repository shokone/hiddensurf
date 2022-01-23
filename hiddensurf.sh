#!/bin/bash

# Script to Surf the Internet Anonymously
# 
# Description:
# Implementing Tor, I2P, Privoxy, Arm-Tor and MacChanger
# for a simple and better privacy and security
#
# Author: Shokone
# Version: 1.0
# 

# Declare basic vars
NAME=$(basename "${0}" .sh)
VERSION="1.0"
AUTHOR="Shokone"
CONFIG_FILE="/etc/default/hiddensurf.conf"
GREEN='\033[1;92m'
RED='\033[1;91m'
RESETCOLOR='\033[1;00m'


## Check if user is root
root_check() {
	[[ "$(id -u)" -ne 0 ]] && echo -e "[${RED}ERROR${RESETCOLOR}] This script must run as root." && exit 1
}


## Check config file
config_check() {
	# Check if config file exists
	[ ! -f "${CONFIG_FILE}" ] && echo -e "[${RED}ERROR${RESETCOLOR}] Config file /etc/default/hiddensurf.conf not exists." && exit 1
	# And load it
	. "${CONFIG_FILE}"
}

#### BASIC FUNCTIONS ####

## Usage info
usage() {
	echo "${NAME} v${VERSION} by ${AUTHOR}"
	echo ""
	echo "Usage: ${NAME} [action] [Optional [service]]"
	echo "Actions: "
	echo "- start  -> If not specify a service, by default start tor tunneling."
	echo "            Available services: tor privoxy i2p"
	echo "- stop   -> If not specify a service, by default stop all services."
	echo "            Available services: tor privoxy i2p"
	echo "- status -> Show status of all services."
	echo "- change -> If not specify a service, by default change tor relay."
	echo "            Available services: tor mac hostname"
	echo "- wipe   -> Wipe Cache, RAM and swap"
	echo "- update -> Download last version from github."
	echo ""
	exit 0
}


## Function to create notifications
notifyUser() {
	[ -e "/usr/bin/notify-send" ] && /usr/bin/notify-send "${NAME}" "${1}" 
}


## Show current ips
ip_status() {
	systemctl status tor.service | grep "Active: inactive" > /dev/null && \
		echo -e "[INFO] Current IP: $(curl ifconfig.me -s)" || \
		(echo -e "[INFO] Current Proxy IP: $(curl icanhazip.com -s)" && \
		echo -e "[INFO] Current Tor IP: $(curl ipinfo.io -s | jq .ip | sed 's/"//g')")

}


## Update hiddensurf 
update() {
	echo -e "[INFO] Updating..."
	reponame="hiddensurf"
	git clone "https://github.com/shokone/${reponame}.git" "/tmp/${reponame}"
	bash "/tmp/${reponame}/install.sh"
	rm -r "/tmp/${reponame}"
	echo -e "[${GREEN}SUCCESS${RESETCOLOR}] ${NAME} Updated!"
}


#### CLEAN FUNCTIONS ####
## Kill multiple proccess
kill_proccess() {
	[ "${TO_KILL}" != "" ] && killall -q "${TO_KILL}" && echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Killed proccess to prevent leaks."
}

bleachbit_clean() {
	if [ "${OVERWRITE}" == "true" ] ; then
		bleachbit -o -c $(echo "${BLEACHBIT_CLEANERS}") > /dev/null
	else
		bleachbit -c $(echo "${BLEACHBIT_CLEANERS}") > /dev/null
	fi
}


## Clean DHCP
clean_dhcp() {
	/usr/sbin/dhclient -r
	rm -f /var/lib/dhcp/dhclient*
	rm -f /var/lib/dhclient/*
	echo -e "[INFO] DHCP address released"
}


## Wipe Cache, RAM and swap
wipe() {
	echo -e "[INFO] Wiping Cache, RAM and swap-space..."
	sync; echo 3> /proc/sys/vm/drop_caches
	swapoff -a && swapon -a
	sleep 2
	echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Cache, RAM and swap-space Cleaned."
	notifyUser "Cache, RAM and swap-space Cleaned."
}


#### Services functions ####

## Change, Restore or show hostname status
hostname_mgmt() {
	case "$1" in
		change)	
				echo -e "[INFO] Changing Hostname..."
				cp /etc/hostname /etc/hostname.bak
				cp /etc/hosts /etc/hosts.bak
				systemctl stop NetworkManager.service
				CURRENT=$(hostname)
				clean_dhcp
				NEW=$(shuf -n 1 /etc/dictionaries-common/words | sed -r 's/[^a-zA-Z]//g' | awk '{print tolower($0)}')
				echo "${NEW}" > /etc/hostname
				sed -i "s/127.0.1.1.*/127.0.1.1\t${NEW}/g" /etc/hosts

				if [ -f "${HOME}/.Xauthority" ] ; then
					su "${SUDO_USER}" -c "xauth -n list | grep -v ${CURRENT} | cut -f1 -d\ | xargs -i xauth remove {}"
					su "${SUDO_USER}" -c "xauth add $(xauth -n list | tail -1 | sed 's/^.*\//'${NEW}'\//g')"
					echo -e "[${GREEN}SUCCESS${RESETCOLOR}] X authority file updated"
				fi
								
				systemctl start NetworkManager.service
				sleep 5
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] New Hostname: $(hostname)"
				notifyUser "Hostname spoofed"
				;;
		restore)	
				echo -e "[INFO] Restoring Hostname..."
				systemctl stop NetworkManager.service
				clean_dhcp
				[ -e "/etc/hostname.bak" ] && rm /etc/hostname && cp /etc/hostname.bak /etc/hostname
				[ -e "/etc/hosts.bak" ] && rm /etc/hosts && cp /etc/hosts.bak /etc/hosts
				
				systemctl start NetworkManager.service
				sleep 5
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Restored Hostname: $(hostname)"
				notifyUser "Hostname restored"
				;;
		status)
				echo -e "[INFO] Current Hostname: $(hostname)"
				;;
	esac
}


## Configure resolv and dns
resolv_mgmt() {
	case "$1" in
		backup)
				echo -e "[INFO] Backing up resolv.conf..."
				cp /etc/resolv.conf /etc/resolv.conf.bak
				touch /etc/resolv.conf
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] resolv.conf saved"
				echo -e "[INFO] Modifying DNS..."
				echo "nameserver 127.0.0.1" > /etc/resolv.conf
				;;
		start)
				systemctl start resolvconf.service
				systemctl start dnsmasq.service
				;;
		stop)
				systemctl stop resolvconf.service
				killall dnsmasq
				;;
	esac
}


## configure iptables
iptables_mgmt() {
	case "$1" in 
		backup)
				[ ! -f "/etc/network/iptables.rules" ] && iptables-save > /etc/network/iptables.rules
				;;
		change)
				echo -e "[INFO] Creating iptables rules..."
				iptables_mgmt "backup"
				iptables_mgmt "flush"

				# stop resolvconf
				resolv_mgmt "stop"

				# set iptables nat
				iptables -t nat -A OUTPUT -m owner --uid-owner "${TOR_UID}" -j RETURN
				iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 53
				iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53
				iptables -t nat -A OUTPUT -p udp -m owner --uid-owner "${TOR_UID}" -m udp --dport 53 -j REDIRECT --to-ports 53

				# resolve onion domains 
				iptables -t nat -A OUTPUT -p tcp -d 10.192.0.0/10 -j REDIRECT --to-ports 9040
				iptables -t nat -A OUTPUT -p udp -d 10.192.0.0/10 -j REDIRECT --to-ports 9040

				# exlude local addresses
				for network in "${TOR_EXCLUDE},127.0.0.0/9,127.128.0.0/10"; do
					iptables -t nat -A OUTPUT -d "${network}" -j RETURN
				done

				# redirect all other output
				iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports "${TOR_PORT}"
				iptables -t nat -A OUTPUT -p udp -j REDIRECT --to-ports "${TOR_PORT}"
				iptables -t nat -A OUTPUT -p icmp -j REDIRECT --to-ports "${TOR_PORT}"

				# Accept already established connections
				iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

				# Exclude local addresses
				for network in "${TOR_EXCLUDE},127.0.0.0/8"; do
					iptables -A OUTPUT -d "${network}" -j ACCEPT
				done

				# Allow only tor output
				iptables -A OUTPUT -m owner --uid-owner "${TOR_UID}" -j ACCEPT
				iptables -A OUTPUT -j REJECT

				;;
		flush)
				iptables -F
				iptables -t nat -F
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Deleted all iptables rules."
				;;
		restore)
				echo -e "[INFO] Restoring iptables rules..."
				[ -f "/etc/network/iptables.rules" ] && iptables-restore < /etc/network/iptables.rules && rm /etc/network/iptables.rules
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Iptables rules restored."
				;;
	esac
}


## Control tor service
tor_mgmt() {
	case "$1" in
		start)
				hostname_mgmt "change"
				mac_mgmt "change"
				echo -e "[INFO] Killing dangerous applications..."
				kill_proccess
				bleachbit_clean
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Dangerous applications killed."

				resolv_mgmt "backup"

				if [ ! -e /var/run/tor/tor.pid ]; then
					echo -e "[INFO] Starting Tor..." 
					resolv_mgmt "stop"
					systemctl start tor.service
					[[ $? -ne 0 ]] && echo -e "[${RED}ERROR${RESETCOLOR}] An error occurred when try to start tor service" && exit 1 
					echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Tor Started" 
				fi

				# Check iptables 
				iptables_mgmt "change"
				sleep 1
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Tor tunneling ${GREEN}ON${RESETCOLOR}."
				notifyUser "Tor tunneling ON"
				;;
		stop)
				echo -e "[INFO] Killing dangerous applications..."
				kill_proccess
				bleachbit_clean
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Dangerous applications killed."

				iptables_mgmt "restore"

				echo -e "[INFO] Stopping Tor..." 
				systemctl stop tor.service
				[[ $? -ne 0 ]] && echo -e "[${RED}ERROR${RESETCOLOR}] An error occurred when try to stop tor service" && exit 1 
				resolv_mgmt "start"
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Tor stopped succesfully."

				mac_mgmt "restore"
				hostname_mgmt "restore"
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Tor tunneling ${RED}OFF${RESETCOLOR}."
				notifyUser "Tor tunneling OFF"
				;;
		change)
				echo -e "[INFO] Changing Tor relay..."
				systemctl reload tor.service
				sleep 5
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Tor relay changed."
				ip_status
				sleep 1
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Tor relay changed."
				notifyUser "Tor relay changed"
				;;
		status)
				systemctl status tor.service | grep "Active: active" > /dev/null && status="${GREEN}ON${RESETCOLOR}" || status="${RED}OFF${RESETCOLOR}"
				echo -e "[INFO] Tor tunneling status: ${status}"
				;;
	esac
}


## configure mac
mac_mgmt() {
	case "$1" in 
		change)	
				echo -e "[INFO] Spoofing Mac Address..."
				systemctl stop NetworkManager.service
				listifaces=$(ls /sys/class/net | tr '\n' '|' | sed '$s/|$//')
				read -p "Choose and interface [${listifaces}] > " maciface
				ifconfig "${maciface}" down
				macchanger -r "${maciface}"
				ifconfig "${maciface}" up
				macchanger -s "${maciface}" | grep -i current
				systemctl start NetworkManager.service
				sleep 1
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Mac Address Spoofed."
				notifyUser "Mac Address Spoofed"
				;;
		restore)
				echo -e "[INFO] Restoring Mac Address..."
				systemctl stop NetworkManager.service
				listifaces=$(ls /sys/class/net | tr '\n' '|' | sed '$s/|$//')
				read -p "Choose and interface [${listifaces}] > " maciface
				ifconfig "${maciface}" down
				macchanger -p "${maciface}"
				ifconfig "${maciface}" up
				macchanger -s "${maciface}" | grep -i current
				systemctl start NetworkManager.service
				sleep 1
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Mac Address Restored."
				notifyUser "Mac Address Restored"
				;;
		status)
				echo -e "[INFO] Mac Address: "
				listifaces=$(ls /sys/class/net | tr '\n' '|' | sed '$s/|$//')
				read -p "Choose and interface [${listifaces}] > " maciface
				macchanger -s "${maciface}" | grep -i current
				sleep 1
				;;
	esac
}


## configure privoxy
privoxy_mgmt() {
	case "$1" in
		start)
				echo -e "[INFO] Starting privoxy service..."
				systemctl start privoxy.service
				[[ $? -ne 0 ]] && echo -e "[${RED}ERROR${RESETCOLOR}] An error occurred when try to start privoxy service" && exit 1
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Service privoxy started."
				notifyUser "Privoxy daemon ON"
				;;
		stop)
				echo -e "[INFO] Stopping privoxy service..."
				systemctl stop privoxy.service
				[[ $? -ne 0 ]] && echo -e "[${RED}ERROR${RESETCOLOR}] An error occurred when try to stop privoxy service" && exit 1
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] Service privoxy stopped."
				notifyUser "Privoxy daemon OFF"
				;;
		status)
				systemctl status privoxy.service | grep "Active: active" > /dev/null && status="${GREEN}ON${RESETCOLOR}" || status="${RED}OFF${RESETCOLOR}"
				echo -e "[INFO] Privoxy Service Status: ${status}"
				;;
	esac
}


## configure i2p
i2p_mgmt() {
	case "$1" in
		start)
				echo -e "[INFO] Starting I2P service"
				## REVISAR ESTO
				##anonym8 stop
				cp /etc/resolv.conf /etc/resolv.conf.bak
				touch /etc/resolv.conf
				echo 'nameserver 127.0.0.1' > /etc/resolv.conf
				systemctl start i2pd.service
				[[ $? -ne 0 ]] && echo -e "[${RED}ERROR${RESETCOLOR}] An error occurred when try to start i2p service" && exit 1
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] I2P Service ON"
				notifyUser "I2P Daemon ON" 
				;;
		stop)
				
				echo -e "[INFO] Stopping I2P service"
				systemctl stop i2pd.service
				[[ $? -ne 0 ]] && echo -e "[${RED}ERROR${RESETCOLOR}] An error occurred when try to stop i2p service" && exit 1
				[ -e /etc/resolv.conf.bak ] && rm /etc/resolv.conf && cp /etc/resolv.conf.bak /etc/resolv.conf
				echo -e "[${GREEN}SUCCESS${RESETCOLOR}] I2P Service OFF"
				notifyUser "I2P Daemon OFF" 
				;;
		status)
				systemctl status i2pd.service | grep "Active: active" > /dev/null && status="${GREEN}ON${RESETCOLOR}" || status="${RED}OFF${RESETCOLOR}"
				echo -e "[INFO] I2P Service Status: ${status}"
				;;
	esac
}



## main
# check arguments
[[ -z $@ ]] && usage && exit 0 

case "$1" in
	start)
			root_check
			config_check
			if [[ -z "${2}" ]]; then
				tor_mgmt "start"
			else
				case "${2}" in
					tor)
						tor_mgmt "start"
						;;
					privoxy)
						privoxy_mgmt "start"
						;;
					i2p)
						i2p_mgmt "start"
						;;
					*)
						echo -e "[${RED}ERROR${RESETCOLOR}] Service ${2} not exists. Show help for more information." && exit 1
						;;
				esac
				
			fi
			;;
	stop)
			root_check
			config_check
			if [ -z "${2}" ]; then
				tor_mgmt "stop"
				privoxy_mgmt "stop"
				i2p_mgmt "stop"
			else
				case "${2}" in
					tor)
						tor_mgmt "stop"
						;;
					privoxy)
						privoxy_mgmt "stop"
						;;
					i2p)
						i2p_mgmt "stop"
						;;
					*)
						echo -e "[${RED}ERROR${RESETCOLOR}] Service ${2} not exists. Show help for more information." && exit 1
						;;
				esac
			fi
			;;
	status)
			root_check
			config_check
			echo "[INFO] Current status of services:"
			tor_mgmt "status"
			privoxy_mgmt "status"
			i2p_mgmt "status"
			mac_mgmt "status"
			hostname_mgmt "status"
			ip_status
			;;
	change)
			root_check
			config_check
			if [ -z "${2}" ]; then 
				tor_mgmt "change"
			else
				case "${2}" in
					tor)
						tor_mgmt "change"
						;;
					hostname)
						hostname_mgmt "change"
						;;
					mac)
						mac_mgmt "change"
						;;
					*)
						echo -e "[${RED}ERROR${RESETCOLOR}] Service ${2} not exists. Show help for more information." && exit 1
						;;
				esac
			fi
			;;
	restore)
			root_check
			config_check
			case "${2}" in
				hostname)
						hostname_mgmt "restore"
						;;
				mac)
						mac_mgmt "restore"
						;;
				*)
						echo -e "[${RED}ERROR${RESETCOLOR}] Service ${2} not exists. Show help for more information." && exit 1
						;;
			esac
			;;
	wipe)
			root_check
			config_check
			wipe
			;;
	update)
			root_check
			config_check
			update
			;;
	*)
			usage && exit 0
			;;
esac

exit 0
