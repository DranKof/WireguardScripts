#!/bin/bash

# Checks for root -- almost everything in Wireguard requires root access
[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }
echo ""

# Warn before overwriting existing config files
FILE=/etc/wireguard/wg0.conf
if test -f "$FILE"; then
    echo "$FILE already exists, this program will overwrite it."
    echo "Press CTRL+C to abort."
    echo "Terminating active wireguard connection..."
    wg-quick down wg0
    echo ""
fi

# Confirm server IP
echo "What address will clients connect to? (Domain.com, WAN/LAN IP address?)"
IP_S_WAN=$(dig +short myip.opendns.com @resolver1.opendns.com)
IP_S_LAN=$(ip a | grep inet | grep -v 127.0.0.1 | grep -v '::' | awk '{$1=$1};1' | cut -d ' ' -f 2)
IP_S_FQDN=$(hostname -f)
echo "  Auto-detected addresses -"
echo "$IP_S_FQDN"
echo "$IP_S_WAN"
echo "$IP_S_LAN"
echo ""
read -p "> " IP_S_FORCLIENT
echo "You have selected '$IP_S_FORCLIENT' to be the address for clients to connect to."
echo ""

# Confirm network type
echo "What depth of network tunneling will you be using?"
echo "1) Full Tunnel  (Allow clients to access the Internet via this server)"
echo "2) Virtual LAN  (Route client packets to connected private intranet devices)"
echo "3) VPN Only     (Clients can only see devices connected to this WG subnet)"
echo "(1,2,3)"
while true; do
    read -n 1 -s NET_TYPE
    case $NET_TYPE in
        [1]* )
          IP_POOL="0.0.0.0/0, ::/0";
TUNNELLING_OPT="PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE";
          break;;
        [2]* )
          IP_POOL="10.0.0.0/24,172.16.0.0/12,192.168.0.0/16";
TUNNELLING_OPT="PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE";
          break;;
        [3]* )
          IP_POOL="192.168.101.0/24";
          break;;
    esac
done
echo "Routable IP pool: $IP_POOL"
echo "Routing table addition (if any):"
echo "$TUNNELLING_OPT"
echo ""
echo ""

# Confirm UDP port
echo "Which UDP port would you like to use? (Default: 51820)"
read -p "> " PORT
if [ -z "$PORT" ]; then
  PORT="51820"
fi
echo "Your selected port is: $PORT"
echo ""
echo ""

# Confirm DNS server for clients
echo "Enter IP for a preferred DNS for clients, leave blank for none:"
read -p "> " C_DNS
if [ -z "$C_DNS" ]; then
  C_DNS="# no DNS server preference"
  echo "No DNS server will be assigned in client configs"
else
  C_DNS="DNS = $C_DNS"
  echo "DNS entry for clients:  $C_DNS"
fi
echo ""
echo ""

# Generate keys and assign default settings
echo "...Generating keys and default settings."
S_PRIVKEY=$(wg genkey)
S_PUBKEY=$(wg pubkey <<< $S_PRIVKEY)
IP_S_WG="192.168.101.1/32"
C_PRIVKEY=$(wg genkey)
C_PUBKEY=$(wg pubkey <<< $C_PRIVKEY)
IP_C="192.168.101.99/32"
IP_POOL="192.168.101.0/24"


# Create server file
echo "...Creating server config file: $FILE"
echo "[Interface] # Server: Primary
SaveConfig = True
PrivateKey = $S_PRIVKEY
Address = $IP_S_WG
ListenPort = $PORT
$TUNNELLING_OPT

[Peer] # Client: Test Client
PublicKey = $C_PUBKEY
AllowedIPs = $IP_C" > /etc/wireguard/wg0.conf

# Create test client file
echo "...Creating test client config file: ./client.conf"
echo "[Interface] # Client: Test Client
PrivateKey = $C_PRIVKEY
ListenPort = $PORT
Address = $IP_C
$C_DNS

[Peer] #  Server: Primary
PublicKey = $S_PUBKEY
AllowedIPs = $IP_POOL
Endpoint = $IP_S_FORCLIENT:$PORT
PersistentKeepalive = 25" > ./client.conf
echo ""

# Show user client output for copy-paste if accessing via ssh
echo "  Test client config (cat ./client.conf):"
echo "=================================================="
cat ./client.conf
echo "=================================================="
echo ""

# Launch Wireguard
echo "...Config files generated, launching wg0..."
wg-quick up wg0
echo ""

# Prompt for termbin upload (insecure, naturally) for convenience
echo "Would you like to upload client config to termbin?"
echo "1) Yes, the whole thing (insecure, but might be more convenient)"
echo "2) Yes, but only the client private key and server public key"
echo "3) NO."
echo "(1,2,3)"
while true; do
    read -n 1 -s TERM_BIN
    case $TERM_BIN in
        [1]* )
          echo "Hyperlink to client configuration:"
          cat ./client.conf | nc termbin.com 9999
          echo "Use 'curl hyperlink' to view on remote terminal"
          break;;
        [2]* )
          echo "Hyperlink to keys (this might take a second):"
          echo "Client Private Key = $C_PRIVKEY
Server Public Key = $S_PUBKEY" | nc termbin.com 9999
          echo "Use 'curl hyperlink' to view on remote terminal"
          break;;
        [3]* )
          # do nothing
          break;;
    esac
done

# The end.
echo "Program gracefully exited."
exit 0