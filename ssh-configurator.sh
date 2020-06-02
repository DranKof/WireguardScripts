#!/bin/bash

# Checks for root
[[ $UID == 0 ]] || { echo "* You must be root to run this."; exit 1; }

# Set shared vals
TITLE="SSH Configurator"
# Automatically get line and column lengths of current console screen
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

do_ssh_toggle() {
  get_service_status "ssh"
  if [ "$STATUS" = "ACTIVE" ]; then
    echo "..SSH is active"
    if (whiptail --title "$TITLE" --yesno "Would you you like SSH enabled?\n\nCurrent SSH Status: ACTIVE" $LINS $COLS); then
      echo "....User chose to keep it activated."
    else
      echo "....User chose to deactivate it."
      # remove from startup
      update-rc.d ssh disable &&
      # stop service
      invoke-rc.d ssh stop
    fi
  else
    echo "..SSH is inactive"
    if (whiptail --title "$TITLE" --yesno "Would you you like SSH enabled?\n\nCurrent SSH Status: INACTIVE" $LINS $COLS --defaultno); then
      echo "....User chose to activate it."
      # generate keys at default paths for any missing key types
      ssh-keygen -A &&
      # add to startup
      update-rc.d ssh enable &&
      # start service
      invoke-rc.d ssh start
    else
      echo "....User chose to keep it inactive."
    fi
  fi
}

do_main_menu() {
  get_service_status "ssh"
  MENU_OPT=$(whiptail --title "$TITLE" --menu "SSH Configurator Main Menu" $LINES $COLUMNS $(($LINES-8)) \
    --cancel-button Exit --ok-button Select \
    "TS (Toggle SSH)" "Enable/Disable SSH server (Currently: $STATUS)" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    echo "In Main Menu, you chose: Exit"
    echo "..Program gracefully exited."
    exit 0
  elif [ $RET -eq 0 ]; then
    echo "In Main Menu, you chose: $MENU_OPT"
    case "$MENU_OPT" in
      TS*)
        do_ssh_toggle ;;
      *)
        whiptail --msgbox "* Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "* There was an error running option $MENU_OPT" 20 60 1
  fi
}

while true; do
  do_main_menu
done

echo "* Program exited unexpectedly."
exit 1
