#!/bin/bash

# Checks for root -- almost everything in Wireguard requires root access
[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

# Checking for private/public key pair

# Generating keys
PRIVKEY=$(wg genkey)
PUBKEY=$(wg pubkey <<< $PRIVKEY)
# wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key

echo "Private key: $PRIVKEY"
echo "Public key: $PUBKEY"

# Set shared vals
TITLE="Wireguard Configurator"
eval `resize`
LINS=$(($LINES/2))
COLS=$(($COLUMNS/2))
whiptail --title "$TITLE" --msgbox "Welcome to the $TITLE\n\nBy Darren M. Stults\n\n\n\nAll your base are belong to us." $LINS $COLS

get_service_status() {
  SERVICE=$1
  if systemctl is-active --quiet $SERVICE; then
    STATUS="ACTIVE"
  else
    STATUS="INACTIVE"
  fi
}

do_wg_toggle() {
  get_service_status "wg"
  if [ "$STATUS" = "ACTIVE" ]; then
    echo "..WG is active"
    if (whiptail --title "$TITLE" --yesno "Would you you like WG enabled?\n\nCurrent WG Status: ACTIVE" $LINS $COLS); then
      echo "....User chose to keep it activated."
    else
      echo "....User chose to deactivate it."
      # remove from startup
      update-rc.d wg disable &&
      # stop service
      invoke-rc.d wg stop
    fi
  else
    echo "..WG is inactive"
    if (whiptail --title "$TITLE" --yesno "Would you you like WG enabled?\n\nCurrent WG Status: INACTIVE" $LINS $COLS --defaultno); then
      echo "....User chose to activate it."
      # add to startup
      update-rc.d wg enable &&
      # start service
      invoke-rc.d wg start
    else
      echo "....User chose to keep it inactive."
    fi
  fi
}

do_main_menu() {
  get_service_status "wg"
  MENU_OPT=$(whiptail --title "$TITLE" --menu "Wireguard Configurator Main Menu" $LINES $COLUMNS $(($LINES-8)) \
    --cancel-button Exit --ok-button Select \
    "SC Show Config" "Displays current WG0 config" \
    "TW Toggle WG" "Enable/Disable WG service (Currently $STATUS)" \
    "SS Setup: Server" "Clears WG0 settings and turns computer into a WG server" \
    "SC Setup: Client" "Clears WG0 setings and turns computer in a WG client that connects to a server" \
    "SI Setup: IP Pool" "For servers, configure what IP addresses clients will be able to communicate to each other on" \
    "ST Setup: Tunneling" "For servers, configure whether full tunneling will be enabled" \
    "AP Add Peer" "Adds a connection to a peer" \
    "RP Remove Peer" "Removes a connectionn to a peer" \
    "AC Add Client" "For servers, adds a client connection" \
    "RC Remove Client" "For servers, removes a client connection" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    echo "..In Main Menu, you chose: Exit"
    echo "Program gracefully exited."
    exit 0
  elif [ $RET -eq 0 ]; then
    echo "..In Main Menu, you chose: $MENU_OPT"
    case "$MENU_OPT" in
      SC*)
        echo "I am showing you your wireguard config!" ;;
      TW*)
        do_wg_toggle ;;
      SS*)
        echo "Time to make you a server!" ;;
      SC*)
        echo "Time to make you a plain ol' client!" ;;
      SI*)
        echo "Time to set up IP pools!" ;;
      ST*)
        echo "Time to enable tunneling and packet forwarding!" ;;
      AP*)
        echo "Time to add a peer!" ;;
      RP*)
        echo "Time to remove a peer!" ;;
      AC*)
        echo "Time to add a client!" ;;
      RC*)
        echo "Time to remove a client!" ;;
      *)
        whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $MENU_OPT" 20 60 1
  fi
}

while true; do
  do_main_menu
done

echo "Program exited unexpectedly."
exit 1

