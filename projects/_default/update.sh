#!/bin/bash

#################
# Configuration #
#################

# osm2pgsql - Anzahl Prozessorkerne (Pi1 => max. 1 ; Pi2&Pi3 => max. 4 )
cpuCores=4

# osm2pgsql - RAM für Zwischenspeicher (MB)
ramCache=256


#########################
# Script - only experts #
#########################

_SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# PgSql - Datenbankname
dbnameFilepath=${_SCRIPTPATH}/data/dbname.txt
dbName=$(head -n 1 ${dbnameFilepath})

# Poly-Datei
polyFilepath=${_SCRIPTPATH}/data/poly_file.txt
osmPolyFileUri=$(head -n 1 ${polyFilepath})

# Last Modify
lastModifyFilepath="${_SCRIPTPATH}/data/last_modify.txt"
LAST_MODIFY=$(head -n 1 ${lastModifyFilepath})
echo $LAST_MODIFY
if [ "${LAST_MODIFY}" == '' ]
then
	echo 'Update kann ohne last_modify nicht gestartet werden!'
	exit 1
fi

# Erzeuge current Modify (wird nach Update gespeichert)
currentModify=$(TZ='UTC' date +%Y-%m-%dT%H:%M:%SZ)

# osm2pgsql - Style-File
osmStyle="${_SCRIPTPATH}/styles/default.style"

# Temp-Path
tmpPath="${_SCRIPTPATH}/tmp"

# OSM PolyFilepath
osmPolyFilepath=${tmpPath}/$(basename "${osmPolyFileUri}")

# Change Filename
changeFilepath="${tmpPath}/change${RANDOM}.osc"

# Convert Filename
conFilepath="${tmpPath}/convert${RANDOM}.osc"

# Cronjob stoppen
${_SCRIPTPATH}/crontab.sh remove ${dbName}


# Download PolyFile
wget -N ${osmPolyFileUri} -P ${tmpPath}

# Download ChangeFile
osmupdate ${LAST_MODIFY} ${changeFilepath}

# No ChangeFile => Abbruch
if [ ! -f "${changeFilepath}" ]
then
	echo 'Keine neuen Daten verfügbar'
	# Cronjob wieder starten
	${_SCRIPTPATH}/crontab.sh add ${dbName} "${cronjob}"
	exit 1
fi

# OsmConvert
osmconvert --hash-memory=240 -B=${osmPolyFilepath} --out-osc ${changeFilepath} >${conFilepath}


# DB-Import: osm2pgsql
sudo -u postgres osm2pgsql --append -s -l -C ${ramCache} --number-processes ${cpuCores} -S ${osmStyle} -d ${dbName} ${conFilepath}

# aktuellen Cronjob holen
cronjobFilepath=${_SCRIPTPATH}/data/cronjob.txt
cronjob=$(head -n 1 ${cronjobFilepath})
# Cronjob wieder starten
if [ -n "${cronjob}" ]
then
	${_SCRIPTPATH}/crontab.sh add ${dbName} "${cronjob}"
fi

# Setze Current Modify
echo $currentModify >"${_SCRIPTPATH}/data/last_modify.txt"

# Logging
echo "${currentModify}" >>"${_SCRIPTPATH}/last_updates.log"

# Lösche Converts
rm ${conFilepath}
rm ${changeFilepath}
