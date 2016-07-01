# OSM Quick Install - Raspberry Pi
```
Dieses Tool ist aktuell in der Experimentierphase
```
OSM Pi soll im Schnellverfahren eine GIS-Testumgebung auf Basis der OpenStreetMap Datenbank erstellen.

### OSM Pi nutzt diese Module
+ PostgreSql 9.4
+ PostGis
+ osm2pgsql
+ osmctools

#### GIS und Verwaltungsprogramme (optional)
+ QGis (Desktop)
+ pgAdmin3 (Desktop)

### OSM Pi Installation

Diese OSM Pi *Alpha-Version* sollte nur auf einem neu angelegten Raspian Image aufgesetzt werden!

```Shell
git clone https://github.com/MS-WebDev/osm-pi
chmod +x ./osm-pi/install.sh
./osm-pi/install.sh
```
Nach der Installation kann der OSM Importer via `osm-pi` gestartet werden. 

### How do - OSM Pi
+ [Raspberry Pi für OSM optimieren](https://github.com/MS-WebDev/osm-pi/wiki/Raspberry-Pi-f%C3%BCr-OSM-optimieren)
