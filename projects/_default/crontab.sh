#!/bin/bash

_SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# action => (add | remove)
action="$1" 
projectName="$2"
cronjob="$3"

# Remove (wird auch bei add ausgeführt) :e.g.: ./crontab.sh remove gis_name
######
if [[ -n "${action}" && -n "${projectName}" ]]
then
	crontab -l > osmpicrontab
	sed --in-place '/'${projectName}'/d' osmpicrontab
	crontab osmpicrontab
	rm osmpicrontab
fi


# Add  :e.g.: ./crontab.sh add gis_name "*/5 * * * * ./prj_path/update.sh"
######
if [[ "${action}" == "add" && -n "${projectName}" && -n "${cronjob}" ]]
then
	crontab -l > osmpicrontab
	echo "${cronjob}" >> osmpicrontab
	crontab osmpicrontab
	rm osmpicrontab
fi
