#!/bin/bash
echo "What WAN address would you prefer to use? (Either domain.com or IP address?"
read -p "> " IP_S_WAN
echo "Your server's WAN address is: $IP_S_WAN"
echo ""
echo ""
echo "What kind of network forwarding do you wish to enable?"
echo "1) Full Tunnel  (Allow clients to access Internet from this server)"
echo "2) Full LAN  (Route client packets to connected intranet devices)"
echo "3) VPN Only  (Clients can only see the server and each other)"
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
echo "Routing table addition:"
echo "$TUNNELLING_OPT"
echo ""
echo ""
echo "Which UDP port would you like to use? (Default: 51820)"
read -p "> " PORT
if [ -z "$PORT" ]; then
  PORT="51820"
fi
echo "Your selected port is: $PORT"
echo ""
echo ""
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
echo "...Generating keys and default settings."
# Generate keys and assign default settings
S_PRIVKEY=$(wg genkey)
S_PUBKEY=$(wg pubkey <<< $S_PRIVKEY)
IP_S="192.168.101.1/32"
C_PRIVKEY=$(wg genkey)
C_PUBKEY=$(wg pubkey <<< $C_PRIVKEY)
IP_C="192.168.101.99/32"
IP_POOL="192.168.101.0/24"
echo "...Creating server config file: /etc/wireguard/wg0.conf"
echo "[Interface] # Server: Primary
SaveConfig = True
PrivateKey = $S_PRIVKEY
Address = $IP_S
ListenPort = $PORT
$TUNNELLING_OPT

[Peer] # Client: Test Client
PublicKey = $C_PUBKEY
AllowedIPs = $IP_C" > /etc/wireguard/wg0.conf
echo "...Creating test client config file: ./client.conf"
echo "[Interface] # Client: Test Client
PrivateKey = $C_PRIVKEY
ListenPort = $PORT
Address = $IP_C
$C_DNS

[Peer] #  Server: Primary
PublicKey = $S_PUBKEY
AllowedIPs = $IP_POOL
Endpoint = $IP_S_WAN:$PORT
PersistentKeepalive = 25" > ./client.conf
echo ""
echo "  Test client config (cat ./client.conf):"
echo "=================================================="
cat ./client.conf
echo "=================================================="
echo ""
echo "...Config files generated, launching wg0..."
wg-quick up wg0
echo ""
echo "Program gracefully exited."
exit 0
