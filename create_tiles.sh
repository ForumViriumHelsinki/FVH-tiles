#!/bin/bash

BASEDIR=/site/tile.olmap.org
OSMOSISDIR=${BASEDIR}/osmosis
WEBDIR=${BASEDIR}/www
DIR=$(date -I)
TILEDIR=${WEBDIR}/tiles-${DIR}
QATILEDIR=${WEBDIR}/osm-qa-tiles
OSMOSISDAYDIR=${OSMOSISDIR}/${DIR}
SOURCE_PBF="finland-latest.osm.pbf"
ROUTING_PBF="finland-routing.osm.pbf"
BUILDING_PBF="finland-buildings.osm.pbf"

# Create direcoty if it doesn't exist
[ ! -d "${OSMOSISDAYDIR}" ] && mkdir -v ${OSMOSISDAYDIR}
cd ${OSMOSISDAYDIR}

# Download finland-latest.osm.pbf
[ ! -f "${SOURCE_PBF}" ] && wget -q https://download.geofabrik.de/europe/${SOURCE_PBF} -O ${SOURCE_PBF}

#########################################
# Generate ${ROUTING_PBF}
[ ! -f "${ROUTING_PBF}" ] && time osmosis --read-pbf ${SOURCE_PBF} --lp --tf accept-ways highway=* route=* --tf accept-relations type=route,restriction --used-node --lp --write-pbf ${ROUTING_PBF}

# Remove old tiles
rm -Rf ${WEBDIR}/tiles*

# Generate tiles
[ ! -d "${TILEDIR}" ] && time docker run --rm -v ${TILEDIR}:/var/app/db/ -v ${OSMOSISDAYDIR}/${ROUTING_PBF}:/var/app/source/input.osm.pbf tuukkah/routeable-tiles

ln -s ${TILEDIR} ${WEBDIR}/tiles

# Start tile api server
docker start routeable-tiles-api

# Fetch json tiles from api server
cd ${WEBDIR}/routable-tiles
time find ${TILEDIR}/14 -type f -printf '%P\n'|sed -e 's#^\([^.]*\).*#http://localhost:8002/14/\1#' | sort | uniq | xargs wget -q -x -nH

# Stop tile api server
docker stop routeable-tiles-api

# Gzip all the files
time find . -type f ! -name "*gz" | xargs gzip -f

#########################################
# Generate ${BUILDING_PBF}

cd ${OSMOSISDAYDIR}

time osmosis \
  --read-pbf "${SOURCE_PBF}" \
  --log-progress \
  --tag-filter reject-relations \
  --tag-filter reject-ways \
  --tag-filter accept-nodes entrance=* amenity=loading_dock addr:housenumber=* \
  \
  --read-pbf "${SOURCE_PBF}" \
  --log-progress \
  --tag-filter reject-relations \
  --tag-filter accept-ways building=* building:part=* \
  --used-node \
  \
  --read-pbf "${SOURCE_PBF}" \
  --log-progress \
  --tag-filter accept-relations type=associated_entrance building=* building:part=* \
  --used-way \
  --used-node \
  \
  --merge --merge \
  --write-pbf "${BUILDING_PBF}"

# Remove old tiles
rm -Rf ${WEBDIR}/tiles*

# Generate tiles
[ ! -d "${TILEDIR}" ] && time docker run --rm -v ${TILEDIR}:/var/app/db/ -v ${OSMOSISDAYDIR}/${BUILDING_PBF}:/var/app/source/input.osm.pbf tuukkah/routeable-tiles

ln -s ${TILEDIR} ${WEBDIR}/tiles

# Start tile api server
docker start routeable-tiles-api

# Fetch json tiles from api server
cd ${WEBDIR}/building-tiles
time find ${TILEDIR}/14 -type f -printf '%P\n'|sed -e 's#^\([^.]*\).*#http://localhost:8002/14/\1#' | sort | uniq | xargs wget -x -nH

# Stop tile api server
docker stop routeable-tiles-api

# Gzip all the files
time find . -type f ! -name "*gz" | xargs gzip -f


# Create mbtiles file for QA tiles
cd ${OSMOSISDAYDIR}
time osmium export -c ${OSMOSISDIR}/osm-qa-tile.osmiumconfig --overwrite -f geojsonseq -r -o - --verbose ${OSMOSISDAYDIR}/${SOURCE_PBF} | /usr/local/bin/tippecanoe -q -l osm -n finland-latest -o "${OSMOSISDAYDIR}/finland-latest.mbtiles" -f -z12 -Z12 -ps -pf -pk -P -b0 -d20

rm -Rf ${QATILEDIR}
time /site/tile.olmap.org/venv/bin/mb-util --image_format=pbf ${OSMOSISDAYDIR}/finland-latest.mbtiles ${QATILEDIR}

cp -a ${OSMOSISDAYDIR}/*.* ${WEBDIR}/downloads/

