#!/bin/bash

#################
# Configuration #
#################

# PgSql - Datenbankname
dbName='gis_andorra'

# OSM Quelldatei
osmFileUri='http://download.geofabrik.de/europe/andorra-latest.osm.pbf'

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

# terminate active connections
psql -U postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='${dbName}';"

# Entferne alte Datenbank
psql -U postgres -c "DROP DATABASE ${dbName};"

# Erstelle Datenbank
psql -U postgres -c "CREATE DATABASE ${dbName} OWNER postgres ENCODING 'UTF8';"

# PostGis+hstore Erweiterung hinzufuegen
psql -U postgres -d ${dbName} -c "CREATE EXTENSION postgis;CREATE EXTENSION hstore;"

# OsmConvert
osmconvert --drop-author --drop-version --out-pbf ${osmFilepath} >${conFilepath}

# DB-Import: osm2pgsql
osm2pgsql -U postgres -c -s -l -C ${ramCache} --drop --number-processes ${cpuCores} -S ${osmStyle} -d ${dbName} ${conFilepath}

# Lösche Convert
rm ${conFilepath}

