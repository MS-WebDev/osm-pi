#!/bin/bash

_SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BACKTITLE="v0.1-alpha - keys: tab | space | arrows"

# Importer Menu
goto_importerMenu() {
	
	if (whiptail --title="OSM Pi - Importer" --backtitle "$BACKTITLE" --yesno "\nDieser Vorgang kann ggf. einige Stunden dauern. Den OSM-Import jetzt starten?" 12 60)
	then		
		${_SCRIPTPATH}/importer.sh
		read -p 'Script beendet, weiter... [ENTER]'
	fi
}

# Main Menu
while true; do
	OPTION=$(whiptail --title="OSM Pi - Importer" --backtitle "$BACKTITLE" --cancel-button "Beenden" --menu "" 15 60 4 \
	"1" "Script ausführen" \
	"2" "Script bearbeiten" \
	"3" "OSM Style-Datei bearbeiten" 3>&1 1>&2 2>&3)

	exitstatus=$?
	if [ $exitstatus = 0 ]
	then
		case "$OPTION" in
			1*)
				goto_importerMenu
				;;
			2*)
				sudo nano ${_SCRIPTPATH}/importer.sh
				;;
			3*)
				sudo nano ${_SCRIPTPATH}/styles/default.style
				;;
		esac
	else
		exit 1
	fi
done
