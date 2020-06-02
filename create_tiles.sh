#!/bin/bash

BASEDIR=/site/tile.olmap.org
OSMOSISDIR=${BASEDIR}/osmosis
WEBDIR=${BASEDIR}/www
DIR=$(date -I)
TILEDIR=${WEBDIR}/tiles-${DIR}
QATILEDIR=${WEBDIR}/osm-qa-tiles
OSMOSISDAYDIR=${OSMOSISDIR}/${DIR}

# Create direcoty if it doesn't exist
[ ! -d "${OSMOSISDAYDIR}" ] && mkdir -v ${OSMOSISDAYDIR}
cd ${OSMOSISDAYDIR}

# Download finland-latest.osm.pbf
[ ! -f "finland-latest.osm.pbf" ] && wget -q https://download.geofabrik.de/europe/finland-latest.osm.pbf -O finland-latest.osm.pbf

# Generate finland-routing.osm.pbf
[ ! -f "finland-routing.osm.pbf" ] && time osmosis --read-pbf finland-latest.osm.pbf --lp --tf accept-ways highway=* route=* --tf accept-relations type=route,restriction --used-node --lp --write-pbf finland-routing.osm.pbf

# Remove old tiles
rm -Rf ${WEBDIR}/tiles*

# Generate tiles
[ ! -d "${TILEDIR}" ] && time docker run --rm -v ${TILEDIR}:/var/app/db/ -v ${OSMOSISDAYDIR}/finland-routing.osm.pbf:/var/app/source/input.osm.pbf tuukkah/routeable-tiles

ln -s ${TILEDIR} ${WEBDIR}/tiles

# Start tile api server
docker start routeable-tiles-api

# Fetch json tiles from api server
cd ${WEBDIR}/routable-tiles
time find ${TILEDIR}/14 -type f -printf '%P\n'|sed -e 's#^\([^.]*\).*#http://localhost:8002/14/\1#' | sort | uniq | xargs wget -x -nH

# Stop tile api server
docker stop routeable-tiles-api

# Gzip all the files
time find . -type f ! -name "*gz" | xargs gzip -f

# Create mbtiles file for QA tiles
cd ${OSMOSISDAYDIR}
time osmium export -c ${OSMOSISDIR}/osm-qa-tile.osmiumconfig --overwrite -f geojsonseq -r -o - --verbose ${OSMOSISDAYDIR}/finland-latest.osm.pbf | /usr/local/bin/tippecanoe -q -l osm -n finland-latest -o "${OSMOSISDAYDIR}/finland-latest.mbtiles" -f -z12 -Z12 -ps -pf -pk -P -b0 -d20

# Use mb-util to create QA tiles
rm -Rf ${QATILEDIR}
time /site/tile.olmap.org/venv/bin/mb-util --image_format=pbf ${OSMOSISDAYDIR}/finland-latest.mbtiles ${QATILEDIR}

cp -a ${OSMOSISDAYDIR}/*.* ${WEBDIR}/downloads/
