import datetime
import requests
from dateutil.parser import parse

static_urls = [
    'https://tile.olmap.org/routable-tiles/14/9327/4742',
    'https://tile.olmap.org/building-tiles/14/9327/4742',
    'https://tile.olmap.org/osm-qa-tiles/12/2331/1185.pbf',
]

overpass_urls = [
    'https://overpass.rwqr.org/api/interpreter?data=[out%3Ajson]%3Bnode[%22entrance%22](60.161%2C24.931%2C60.162%2C24.932)%3Bout%3B',
]

problems = []
oks = []

for u in static_urls:
    res = requests.head(u)
    now = datetime.datetime.now(tz=datetime.timezone.utc)
    lastmod_header = res.headers.get('Last-Modified')
    if res.status_code == 200:
        if lastmod_header is not None:
            last_modified = parse(lastmod_header)
            age = round((now - last_modified).seconds / (60 * 60), 1)
            if age > 36:
                problems.append([f'ERROR: Last modified is {age} hours old', u])
            elif age > 12:
                problems.append([f'WARNING: Last modified is {age} hours old', u])
            else:
                oks.append([f'OK {res.status_code}: Last modified is {age} hours old', u])
        else:
            problems.append([f'WEIRD: Last modified does not exist, but status is OK', u])
    else:
        problems.append([f'ERROR: status code was {res.status_code}', u])

for u in overpass_urls:
    res = requests.get(u)
    if res.status_code == 200:
        data = res.json()
        ele_cnt = len(data['elements'])
        now = datetime.datetime.now(tz=datetime.timezone.utc)
        timestamp_osm_base = data['osm3s']['timestamp_osm_base']
        ts = parse(timestamp_osm_base)
        age = round((now - ts).seconds / (60 * 60), 1)
        if age > 36:
            problems.append([f'ERROR: Last modified is {age} hours old', u])
        elif age > 12:
            problems.append([f'WARNING: Last modified is {age} hours old', u])
        else:
            oks.append([f'OK {res.status_code}: OSM base timestamp is {age} hours old', u])
    else:
        problems.append([f'ERROR: status code was {res.status_code}', u])

print('PROBLEMS:')
for p in problems:
    print(f'{p[0]} {p[1]}')
print('OKs:')
for p in oks:
    print(f'{p[0]} {p[1]}')
