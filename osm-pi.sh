#!/bin/bash

_SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BACKTITLE="v0.2-alpha - keys: tab | space | enter | arrows"

# Zeige Meldungen ($1 => title; $2 => msg)
show_message() {
	whiptail --title "$1" --msgbox "$2" 12 78
}


# Import starten ($1 => projectName)
goto_import() {
	
	projectName=$1
	projectPath=${_SCRIPTPATH}/projects/${projectName}
	planetFileUri=$(head -n 1 ${projectPath}/data/planet_file.txt)
	
	# Prüfung auf Planet-File
	if [[ "${planetFileUri}" != *".osm.pbf" ]]
	then
		if (whiptail --title="Fehler: Keine Planet-File - ${projectName}" --backtitle "$BACKTITLE" --yesno "\nImport konnte nicht gestartet werden: Für dieses Projekt (${projectName}) wurde keine OSM-Quelldatei im *.osm.pbf Format angegeben. Möchtest du jetzt eine Quelldatei angeben?" 12 78)
		then
			goto_setPlanetFile ${projectName}
			# Nach Eingabe nochmal prüfen
			goto_import ${projectName}
		fi
		return 0
	fi	
	
	if (whiptail --title="Import starten - ${projectName}" --backtitle "$BACKTITLE" --yesno "\nVorsicht: Die aktuelle Datenbank wird gelöscht und neu aufgesetzt! Ein eventuell gesetzter Update-Intervall wird ebenfalls entfernt!\n\nDieser Vorgang kann ggf. einige Stunden dauern. Den OSM-Import jetzt starten?" 12 78)
	then
		# Remove Cronjob
		${projectPath}/crontab.sh remove ${projectName}
		# lösche Cronjob-File
		rm ${projectPath}/data/cronjob.txt
		# Import starten
		${_SCRIPTPATH}/projects/${projectName}/import.sh
		read -p 'Script beendet, weiter... [ENTER]'
	fi
}

# Update aktivieren ($1 => projectName)
goto_update() {	
	
	projectName=$1
	projectPath=${_SCRIPTPATH}/projects/${projectName}
	updateSriptpath=${_SCRIPTPATH}/projects/${projectName}/update.sh	
	
	# Prüfung auf Last-Modify
	lastModify=$(head -n 1 ${projectPath}/data/last_modify.txt)
	if [[ "${lastModify}" != *"Z" ]]
	then
		show_message "Fehler: Kein Last-Modify - ${projectName}" "\nFür dieses Projekt (${projectName}) existiert kein Zeitstempel der letzten Modifikation! Updates können erst nach einem Import ausgeführt werden."
		return 0
	fi
	
	# Prüfung auf Poly-File
	polyFileUri=$(head -n 1 ${projectPath}/data/poly_file.txt)
	if [[ "${polyFileUri}" != *".poly" ]]
	then
		if (whiptail --title="Fehler: Keine Poly-File - ${projectName}" --backtitle "$BACKTITLE" --yesno "\nFür dieses Projekt (${projectName}) wurde keine Poly-Datei im *.poly Format angegeben. Ohne Poly-File können keine passenden Änderungen in die Datenbank eingepflegt werden! Möchtest du jetzt eine Poly-Datei angeben?" 12 78)
		then
			goto_setPolyFile ${projectName}
		else
			return 0
		fi
	fi
	
	cronjobFilepath=${projectPath}/data/cronjob.txt
	cronjobOld=$(head -n 1 ${cronjobFilepath})
	if [ ! -n "${cronjobOld}" ]
	then
		cronjobOld='none'
	fi
	
	intervall=$(whiptail --title="Update - ${projectName}" --backtitle "$BACKTITLE" --radiolist "\nAktuell gesetzter Cronjob:\n${cronjobOld}\n\nWähle ein Update-Intervall aus (Leertaste):" 18 78 5 \
	"none" "Kein Update ausführen" ON \
	"*/2 * * * *" "alle 2 Minuten" OFF \
	"*/10 * * * *" "alle 10 Minuten" OFF \
	"*/30 * * * *" "alle 30 Minuten" OFF \
	"@hourly" "stündlich" OFF 3>&1 1>&2 2>&3)
	
	exitstatus=$?
	if [ $exitstatus = 0 ]
	then
		if [ "${intervall}" != "none" ]
		then
			# Add Cronjob
			cronjob="${intervall} ${updateSriptpath}"
			${projectPath}/crontab.sh add ${projectName} "${cronjob}"
			# Setze Cronjob-Settings
			echo "${cronjob}" >${projectPath}/data/cronjob.txt
			# Meldung werfen
			show_message "Cronjob hinzugefügt" "Deine Datenbank wird nun regelmäßig aktualisiert - Folgender Cronjob wurde gesetzt:\n${cronjob}"
		else
			# Remove Cronjob
			${projectPath}/crontab.sh remove ${projectName}			
			# lösche Cronjob-File
			rm ${projectPath}/data/cronjob.txt
			# Meldung werfen
			show_message "Cronjob entfernt" "Die regelmäßige Aktualisierung deiner Datenbank wurde gestoppt. Es werden keine Updates ausgeführt."
		fi
		
		
	fi
}


# Meine Projekte - Menü
goto_myProjects() {
	
	prjList=()
	shopt -s nullglob
	FOLDERS=(${_SCRIPTPATH}/projects/*)	
	for folder in "${FOLDERS[@]}"; do
		if [[ "$folder" != *"_default" ]]
		then
			prjList+=(${folder##*/} "")
		fi
	done
	
	# Prüfung auf Projektanzahl
	if [[ ${#prjList[@]} -lt 1 ]]
	then
		if (whiptail --title="Keine Projekte gefunden" --backtitle "$BACKTITLE" --yesno "\nEs wurden keine Projekte gefunden! Möchtest du jetzt ein neues Projekt erstellen?" 12 78)
		then
			goto_newProject
			goto_myProjects
		fi
		return 0
	fi
	
	projectName=$(whiptail --title="Meine Projekte" --backtitle "$BACKTITLE" --cancel-button "Zurück" --menu "" 15 60 6 "${prjList[@]}" 3>&1 1>&2 2>&3)
	
	exitstatus=$?
	if [ $exitstatus = 0 ]
	then
		goto_currentProject ${projectName}
	fi
	
}

# Neues Projekt erstellen
goto_newProject() {	
	
	projectName=$(whiptail --title "Neues Projekt erstellen" --inputbox "\nDer Projektname ist gleichzeitig der Datenbankname (e.g.: gis_andorra)" 12 78 gis_ 3>&1 1>&2 2>&3)
	
	exitstatus=$?
	if [ $exitstatus = 0 ]
	then
		dbName=$projectName
		# terminate active connections
		sudo -u postgres psql -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='${dbName}'"

		# Entferne alte Datenbank
		sudo -u postgres psql -c "DROP DATABASE ${dbName}"

		# Erstelle Datenbank
		sudo -u postgres psql -c "CREATE DATABASE ${dbName} OWNER postgres ENCODING 'UTF8'"

		# PostGis+hstore Erweiterung hinzufuegen
		sudo -u postgres psql -d ${dbName} -c "CREATE EXTENSION postgis;CREATE EXTENSION hstore;"
	
		# _default Ordner kopieren
		cp -r ${_SCRIPTPATH}/projects/_default ${_SCRIPTPATH}/projects/${projectName}
		
		# dbname an Projekt übergeben
		echo ${dbName} >${_SCRIPTPATH}/projects/${projectName}/data/dbname.txt
		
		# Meldung ausgeben
		show_message "Projekt erfolgreich erstellt" "Dein neues Projekt '${projectName}' kann jetzt verwendet werden - dieses findest du unter dem Reiter 'Meine Projekte'."
		
	else
		echo 'ende'
	fi
}

# Projekt Menü ($1 => projectName)
goto_currentProject() {
	projectName=$1
	projectPath=${_SCRIPTPATH}/projects/${projectName}	
	
	while true; do
		OPTION=$(whiptail --title="Projekt - ${projectName}" --backtitle "$BACKTITLE" --cancel-button "Zurück" --menu "" 15 60 6 \
		"1" "Konfiguration" \
		"2" "Import starten" \
		"3" "Update (de)aktivieren" \
		"4" "Datenbank leeren" \
		"5" "Projekt löschen" 3>&1 1>&2 2>&3)
		
		exitstatus=$?
		if [ $exitstatus = 0 ]
		then
			case "$OPTION" in
				1*)
					goto_configureProject ${projectName}
					;;
				2*)
					goto_import ${projectName}
					;;
				3*)
					goto_update ${projectName}
					;;
				4*)
					if (whiptail --title "Datenbank leeren" --yesno "Soll die Datenbank '${projectName}' wirklich geleert werden?" 10 78) then
						# Remove Cronjob
						${projectPath}/crontab.sh remove ${projectName}
						# lösche Cronjob-File
						rm ${projectPath}/data/cronjob.txt
						# terminate active connections
						sudo -u postgres psql -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='${projectName}'"
						# Entferne alte Datenbank
						sudo -u postgres psql -c "DROP DATABASE ${projectName}"
						# Erstelle Datenbank
						sudo -u postgres psql -c "CREATE DATABASE ${projectName} OWNER postgres ENCODING 'UTF8'"
						# PostGis+hstore Erweiterung hinzufuegen
						sudo -u postgres psql -d ${projectName} -c "CREATE EXTENSION postgis;CREATE EXTENSION hstore;"
						# Last modify entfernen
						rm ${projectPath}/data/last_modify.txt
						# Meldung ausgeben
						show_message "Datenbank leeren" "Die Datenbank '${projectName}' wurde erfolgreich geleert."
					fi
					;;
				5*)
					# löschen
					if (whiptail --title "Projekt löschen" --yesno "Soll das Projekt '${projectName}' und die zugehörige Datenbank wirklich gelöscht werden?" 10 78) then
						# true => löschen
						goto_delProject ${projectName}
						# Zurück zum Hauptmenü
						break
					fi
					;;
			esac
		else
			break
		fi	
	done
}

# Projekt Konfiguration ($1 => projectName)
goto_configureProject() {
	projectName=$1
	projectPath=${_SCRIPTPATH}/projects/${projectName}	
	
	while true; do
		OPTION=$(whiptail --title="Konfiguration - ${projectName}" --backtitle "$BACKTITLE" --cancel-button "Zurück" --menu "" 15 60 6 \
		"1" "OSM-Quelldatei angeben" \
		"2" "Poly-Datei angeben" \
		"3" "OSM Style-Datei bearbeiten" 3>&1 1>&2 2>&3)
		
		exitstatus=$?
		if [ $exitstatus = 0 ]
		then
			case "$OPTION" in
				1*)
					goto_setPlanetFile ${projectName}
					;;
				2*)
					goto_setPolyFile ${projectName}
					;;
				3*)
					sudo nano ${projectPath}/styles/default.style
					;;
			esac
		else
			break
		fi
	done
}

# Setze Poly-File ($1 => projectName)
goto_setPolyFile() {
	
	projectName=$1
	projectPath=${_SCRIPTPATH}/projects/${projectName}
	
	polyFilepath=${projectPath}/data/poly_file.txt
	polyFileOld=''
	if [ -f ${polyFilepath} ]
	then
		polyFileOld=$(head -n 1 ${polyFilepath})
	fi
	polyFile=$(whiptail --title "Poly-Datei - ${projectName}" --inputbox "\nGib hier die URL der Poly-Datei im *.poly Format an. (e.g.: http://download.geofabrik.de/europe/andorra.poly)" 12 78 ${polyFileOld} 3>&1 1>&2 2>&3)
	if [ "$polyFile" != '' ]
	then
		echo "$polyFile" >${polyFilepath}
	fi
}

# Setze OSM-Quelldatei ($1 => projectName)
goto_setPlanetFile() {
	
	projectName=$1
	projectPath=${_SCRIPTPATH}/projects/${projectName}
	
	planetFilepath=${projectPath}/data/planet_file.txt
	planetFileOld=''
	if [ -f ${planetFilepath} ]
	then
		planetFileOld=$(head -n 1 ${planetFilepath})
	fi
	planetFile=$(whiptail --title "OSM-Quelldatei - ${projectName}" --inputbox "\nGib hier die URL der OSM-Quelldatei im *.osm.pbf Format an. (e.g.: http://download.geofabrik.de/europe/andorra-latest.osm.pbf)" 12 78 ${planetFileOld} 3>&1 1>&2 2>&3)
	if [ "$planetFile" != '' ]
	then
		echo "$planetFile" >${planetFilepath}
	fi
}


# Projekt löschen ($1 => projectName)
goto_delProject() {
	
	projectName=$1
	projectPath=${_SCRIPTPATH}/projects/${projectName}
	
	# Remove Cronjob
	${projectPath}/crontab.sh remove ${projectName}	
	
	# terminate active connections
	sudo -u postgres psql -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='${projectName}'"

	# Entferne alte Datenbank
	sudo -u postgres psql -c "DROP DATABASE ${projectName}"
	
	# Entferne Projekt-Ordner
	rm -r ${_SCRIPTPATH}/projects/${projectName}
	
	# Meldung anzeigen
	show_message "Projekt erfolgreich entfernt" "Das Projekt '${projectName}' inklusive Datenbank wurde erfolgreich entfernt."
	
}

# Main Menu
while true; do
	OPTION=$(whiptail --title="OSM Pi - Manager" --backtitle "$BACKTITLE" --cancel-button "Beenden" --menu "" 15 60 6 \
	"1" "Meine Projekte" \
	"2" "Neues Projekt erstellen" 3>&1 1>&2 2>&3)
	
	exitstatus=$?
	if [ $exitstatus = 0 ]
	then
		case "$OPTION" in
			1*)
				goto_myProjects
				;;
			2*)
				goto_newProject
				;;
		esac
	else
		exit 1
	fi
done
