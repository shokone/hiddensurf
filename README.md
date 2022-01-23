# hiddensurf

HiddenSurf is a script that will allow users to spoof their MAC address, change their hostname and transparently route traffic through Tor (The Onion Router) to provide simple and better user privacy and security. 
Include macchanger, hostname and wipe (Cleans ram/cache & swap-space) features.

### Requirements
Script requirements are:
```shell
- tor 
- macchanger 
- resolvconf 
- dnsmasq 
- privoxy 
- tor-arm 
- libnotify-bin 
- curl 
- bleachbit 
- i2pd 
- jq
```
they'll be automatically installed.


### Supported platforms:

> <h5>Kali Linux</h5>
> <hr />
> <h6>Other Debian-based Linux distros.</h6>


### Install

```shell
git clone https://github.com/shokone/hiddensurf.git
cd hiddensurf
chmod +x install.sh
./install.sh
```


### Usage

```shell
$ hiddensurf help
hiddensurf v1.0 by Shokone

Usage: hiddensurf [action] [Optional [service]]
Actions: 
- start  -> If not specify a service, by default start tor tunneling.
            Available services: tor privoxy i2p
- stop   -> If not specify a service, by default stop all services.
            Available services: tor privoxy i2p
- status -> Show status of all services.
- change -> If not specify a service, by default change tor relay.
            Available services: tor mac hostname
- wipe   -> Wipe Cache, RAM and swap
- update -> Download last version from github.

```