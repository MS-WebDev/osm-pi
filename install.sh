#!/bin/bash

_SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_HOMEPATH=$(eval echo ~${SUDO_USER})


#green=tput setaf 2
G='\033[1;32m'
Y='\033[1;33m'
W='\033[0;37m'
clr='\033c'

# Intro
txt="Die folgende Routine ist für Raspbian/Raspberry Pi geschrieben und sollte nur auf einer Testumgebung ausgeführt werden! \n\nInstallation jetzt starten?"
if (whiptail --title "OSM Pi - Installer" --yesno "$txt" 12 78) then
	echo 'Starte Routine...'
else
	echo 'Routine abgebrochen'
	exit 1
fi

# Update apt-get
echo -e "${G}Update: APT${W}"
sudo apt-get clean
sudo apt-get update

# Install PostgreSql
echo -e "${G}Install: PostgreSql${W}"
sudo apt-get install postgresql-9.4 -y
# Setup PostgreSql
echo -e "${Y}Setup: PostgreSql${W}"
sudo service postgresql stop
#echo 'Change pg_hba.conf file'
sudo -E bash -c "sed --in-place '/host all all localhost md5/d' /etc/postgresql/9.4/main/pg_hba.conf"
sudo -E bash -c 'echo "host all all localhost md5" >>/etc/postgresql/9.4/main/pg_hba.conf'
#sudo -E bash -c "cat >/etc/postgresql/9.4/main/pg_hba.conf <<CMD_EOF
#local all all trust
#host all all 127.0.0.1 255.255.255.255 md5
#host all all 0.0.0.0/0 md5
#host all all ::1/128 md5
#CMD_EOF"
sudo service postgresql start

echo -e "${Y}Change PostgreSql Admin-Password${W}"
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '123456';"
echo 'restart postgresql service'
sudo service postgresql restart
echo 'autorun postgresql service'
sudo update-rc.d postgresql defaults

echo -e "${G}Install: PostGIS${W}"
sudo apt-get install postgis -y

echo -e "${G}Install: osm2pgsql${W}"
sudo apt-get install osm2pgsql -y

echo -e "${G}Install: osmctools${W}"
sudo apt-get install osmctools -y

# pgAdmin3
txt="Mit der Desktop-Anwendung pgAdmin3 können importierte OSM-Datenbanken verwaltet werden.\n\npgAdmin3 jetzt installieren?"
if (whiptail --title "pgAdmin3 - Install" --yesno "$txt" 12 78) then
	echo -e "${G}Install: pgAdmin3${W}"
	sudo apt-get install pgadmin3 -y
fi

# QGis
txt="Mit der Desktop-Anwendung QGis können importierte OSM-Daten visuell dargestellt werden.\n\nQGis jetzt installieren?"
if (whiptail --title "QGis - Install" --yesno "$txt" 12 78) then
	echo -e "${G}Install: QGis${W}"
	sudo apt-get install qgis -y
fi

# Zugriffsrechte setzen
chmod +x ${_SCRIPTPATH}/osm-pi.sh
chmod +x ${_SCRIPTPATH}/projects/_default/import.sh
chmod +x ${_SCRIPTPATH}/projects/_default/update.sh
chmod +x ${_SCRIPTPATH}/projects/_default/crontab.sh

# osm-pi als Alias setzen
sed --in-place '/alias osm-pi=/d' ${_HOMEPATH}/.bash_aliases
echo "alias osm-pi='bash ${_SCRIPTPATH}/osm-pi.sh'" >> ${_HOMEPATH}/.bash_aliases



printf "${clr}"
echo -e "${Y}Installation beendet${W}"
echo 'Du kannst dich nun mit den folgenden Zugangsdaten bei pgAdmin3 oder QGis anmelden und dort auf deine OSM-Datenbanken zugreifen.'
printf "\n"
echo -e "${Y}Deine Zugangsdaten${W}"
echo -e "${G}Host: ${W}localhost"
echo -e "${G}username: ${W}postgres"
echo -e "${G}password: ${W}123456"
printf "\n"
echo -e "Mit dem Aufruf ${G}osm-pi${W} startest du den OSM Importer."
read -p "OSM Pi Importer jetzt starten? (j=ja/n=nein)" confirm

if [ "$confirm" == "j" ]
	then
		echo 'OSM Pi wird gestartet...'
		${_SCRIPTPATH}/osm-pi.sh
		bash
	else
		bash
		exit 1
fi





