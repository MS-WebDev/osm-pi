#!/bin/bash

#################
# Configuration #
#################

# osm2pgsql - Anzahl Prozessorkerne (Pi1 => max. 1 ; Pi2&Pi3 => max. 4 )
cpuCores=4

# osm2pgsql - RAM für Zwischenspeicher (MB)
ramCache=256


#######################
# END - Configuration #
#######################




















#########################
# Script - only experts #
#########################

_SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# PgSql - Datenbankname
dbnameFilepath=${_SCRIPTPATH}/data/dbname.txt
dbName=$(head -n 1 ${dbnameFilepath})

# OSM Quelldatei
planetFilepath=${_SCRIPTPATH}/data/planet_file.txt
osmFileUri=$(head -n 1 ${planetFilepath})

# osm2pgsql - Style-File
osmStyle="${_SCRIPTPATH}/styles/default.style"

# Temp-Path
tmpPath="${_SCRIPTPATH}/tmp"

# OSM Filepath
osmFilepath=${tmpPath}/$(basename "${osmFileUri}")

# Convert Filename
conFilepath="${tmpPath}/convert${RANDOM}.osm.pbf"

# Download Planet File
wget -N ${osmFileUri} -P ${tmpPath}

# Save Last Modify
clockBackward=1 # hour ago
timestampModify=$(stat -c '%Y' ${osmFilepath})
if [ "$timestampModify" != '' ]
then
	lastModify=$(TZ='UTC' date -d @${timestampModify} +%Y-%m-%dT%H:%M:%SZ)
else
	lastModify=$(TZ='UTC' date -d "${clockBackward} hours ago" +%Y-%m-%dT%H:%M:%SZ)
fi
echo $lastModify >"${_SCRIPTPATH}/data/last_modify.txt"

# terminate active connections
sudo -u postgres psql -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='${dbName}';"

# Entferne alte Datenbank
sudo -u postgres psql -c "DROP DATABASE ${dbName};"

# Erstelle Datenbank
sudo -u postgres psql -c "CREATE DATABASE ${dbName} OWNER postgres ENCODING 'UTF8';"

# PostGis+hstore Erweiterung hinzufuegen
sudo -u postgres psql -d ${dbName} -c "CREATE EXTENSION postgis;CREATE EXTENSION hstore;"

# OsmConvert
osmconvert --hash-memory=240 --out-pbf ${osmFilepath} >${conFilepath}

# DB-Import: osm2pgsql
sudo -u postgres osm2pgsql -c -s -l -C ${ramCache} --number-processes ${cpuCores} -S ${osmStyle} -d ${dbName} ${conFilepath}

# Lösche Convert
rm ${conFilepath}

