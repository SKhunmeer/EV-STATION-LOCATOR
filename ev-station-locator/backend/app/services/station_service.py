import json
import os
from math import radians, sin, cos, sqrt, atan2
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from flask import current_app

from app.models import ChargingStation, Connector, Provider


class StationService:
    _cache = {}
    _cache_ttl_seconds = 120

    @staticmethod
    def _demo_allowed():
        return os.getenv('ALLOW_DEMO_DATA', 'false').lower() == 'true' or current_app.config.get('TESTING', False)

    @staticmethod
    def open_charge_map_stations(lat=17.4065, lng=78.4772, radius_km=10.0):
        api_key = os.getenv('OCM_API_KEY')
        if not api_key:
            return []
        cache_key = (round(lat, 3), round(lng, 3), round(radius_km, 1))
        cached = StationService._cache.get(cache_key)
        if cached and (StationService._now() - cached[0]) < StationService._cache_ttl_seconds:
            return cached[1]

        params = urlencode({
            'output': 'json',
            'latitude': lat,
            'longitude': lng,
            'distance': radius_km,
            'distanceunit': 'KM',
            'maxresults': 100,
            'compact': 'true',
            'verbose': 'false',
            'key': api_key,
        })
        request = Request(
            f'https://api.openchargemap.io/v3/poi/?{params}',
            headers={'Accept': 'application/json', 'User-Agent': 'EVStationLocator/1.0'},
        )
        try:
            with urlopen(request, timeout=8) as response:
                payload = json.loads(response.read().decode('utf-8'))
        except (OSError, ValueError):
            return []

        stations = [StationService._open_charge_map_to_station(item, lat, lng) for item in payload]
        StationService._cache[cache_key] = (StationService._now(), stations)
        return stations

    @staticmethod
    def _now():
        import time
        return time.time()

    @staticmethod
    def _open_charge_map_to_station(item, user_lat, user_lng):
        address = item.get('AddressInfo') or {}
        operator = item.get('OperatorInfo') or {}
        connections = item.get('Connections') or []
        # OCM POIs do not provide live connector occupancy. Operational means
        # listed as operational, not that a charger is currently free.
        operational = (item.get('StatusType') or {}).get('IsOperational')
        connectors = [{
            'id': None,
            'connector_type': (connection.get('ConnectionType') or {}).get('Title') or 'Unknown',
            'power_kw': connection.get('PowerKW') or 0,
            'status': 'UNKNOWN' if operational is not False else 'MAINTENANCE',
        } for connection in connections]
        latitude = address.get('Latitude') or user_lat
        longitude = address.get('Longitude') or user_lng
        return {
            'id': item.get('ID'),
            'source': 'openchargemap',
            'reservable': False,
            'provider': operator.get('Title') or 'Open Charge Map',
            'name': address.get('Title') or 'Charging station',
            'latitude': latitude,
            'longitude': longitude,
            'address': address.get('AddressLine1'),
            'city': address.get('Town') or address.get('StateOrProvince'),
            'charging_power_kw': max((connector['power_kw'] for connector in connectors), default=0),
            'price_per_kwh': None,
            'total_connectors': item.get('NumberOfPoints') or len(connectors),
            'available_connectors': None,
            'status': 'UNKNOWN' if operational is not False else 'MAINTENANCE',
            'availability_fresh': False,
            'opening_hours': (item.get('UsageType') or {}).get('Title'),
            'distance_km': round(StationService.haversine(user_lat, user_lng, latitude, longitude), 2),
            'connectors': connectors,
        }

    @staticmethod
    def nearby_stations(lat=17.4065, lng=78.4772, radius_km=10.0):
        live_stations = StationService.open_charge_map_stations(lat, lng, radius_km)
        if live_stations:
            return sorted(live_stations, key=lambda station: station['distance_km'])
        if not StationService._demo_allowed():
            return []
        stations = ChargingStation.query.join(Provider).all()
        result = []
        for station in stations:
            distance_km = StationService.haversine(lat, lng, station.latitude, station.longitude)
            if distance_km <= radius_km:
                station_data = station.to_dict(include_connectors=True)
                station_data['distance_km'] = round(distance_km, 2)
                result.append(station_data)
        return sorted(result, key=lambda s: s['distance_km'])

    @staticmethod
    def search_stations(query=''):
        live_stations = StationService.open_charge_map_stations(
            lat=float(os.getenv('OCM_LATITUDE', 17.4065)),
            lng=float(os.getenv('OCM_LONGITUDE', 78.4772)),
            radius_km=float(os.getenv('OCM_RADIUS_KM', 50)),
        )
        if live_stations:
            if not query:
                return live_stations
            lowered_query = query.lower()
            return [station for station in live_stations if any(
                lowered_query in str(station.get(field) or '').lower()
                for field in ('name', 'provider', 'city', 'address')
            )]
        if not StationService._demo_allowed():
            return []
        if not query:
            return [s.to_dict(include_connectors=True) for s in ChargingStation.query.all()]
        q = f'%{query.lower()}%'
        stations = ChargingStation.query.join(Provider).filter(
            (ChargingStation.name.ilike(q)) |
            (Provider.name.ilike(q)) |
            (ChargingStation.city.ilike(q)) |
            (ChargingStation.address.ilike(q))
        ).all()
        return [s.to_dict(include_connectors=True) for s in stations]

    @staticmethod
    def filter_stations(**kwargs):
        if os.getenv('OCM_API_KEY'):
            stations = StationService.open_charge_map_stations(
                lat=float(os.getenv('OCM_LATITUDE', 17.4065)),
                lng=float(os.getenv('OCM_LONGITUDE', 78.4772)),
                radius_km=float(os.getenv('OCM_RADIUS_KM', 50)),
            )
            search = (kwargs.get('search') or '').lower()
            min_power = float(kwargs.get('min_power') or 0)
            max_price = kwargs.get('max_price')
            availability = kwargs.get('availability')
            result = []
            for station in stations:
                if search and search not in str(station.get('name', '')).lower() and search not in str(station.get('city', '')).lower():
                    continue
                if (station.get('charging_power_kw') or 0) < min_power:
                    continue
                if max_price is not None and (station.get('price_per_kwh') is None or station['price_per_kwh'] > float(max_price)):
                    continue
                if availability == 'available' and station.get('available_connectors') is not None and station['available_connectors'] <= 0:
                    continue
                result.append(station)
            return result
        if not StationService._demo_allowed():
            return []
        stations = ChargingStation.query.join(Provider).all()
        provider = kwargs.get('provider')
        city = kwargs.get('city')
        max_price = kwargs.get('max_price')
        min_power = kwargs.get('min_power', 0)
        availability = kwargs.get('availability')
        search = kwargs.get('search', '')

        filtered = []
        for station in stations:
            if provider and provider.lower() not in station.provider.name.lower():
                continue
            if city and city.lower() not in (station.city or '').lower():
                continue
            if max_price is not None and station.price_per_kwh > float(max_price):
                continue
            if min_power and station.charging_power_kw < float(min_power):
                continue
            if search and search.lower() not in station.name.lower() and search.lower() not in (station.provider.name.lower() if station.provider else '') and search.lower() not in (station.city or '').lower():
                continue
            if availability == 'available' and station.available_connectors <= 0:
                continue
            filtered.append(station.to_dict(include_connectors=True))
        return filtered

    @staticmethod
    def haversine(lat1, lon1, lat2, lon2):
        R = 6371.0
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
        c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c

    @staticmethod
    def get_station_by_id(station_id):
        return ChargingStation.query.get_or_404(station_id)

    @staticmethod
    def get_live_status():
        if os.getenv('OCM_API_KEY'):
            stations = StationService.open_charge_map_stations(
                lat=float(os.getenv('OCM_LATITUDE', 17.4065)),
                lng=float(os.getenv('OCM_LONGITUDE', 78.4772)),
                radius_km=float(os.getenv('OCM_RADIUS_KM', 50)),
            )
            return [{'station_id': station['id'], 'station_name': station['name'], 'status': 'UNKNOWN', 'available_connectors': None, 'congestion': 'UNAVAILABLE'} for station in stations]
        if not StationService._demo_allowed():
            return []
        stations = ChargingStation.query.all()
        data = []
        for station in stations:
            data.append({
                'station_id': station.id,
                'station_name': station.name,
                'status': station.status,
                'available_connectors': sum(c.status == 'AVAILABLE' for c in station.connectors),
                'connectors': [c.to_dict() for c in station.connectors],
            })
        return data
