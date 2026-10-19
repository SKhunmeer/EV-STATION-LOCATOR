"""Transparent seven-factor station ranking."""
from math import inf

WEIGHTS = {'compatibility': .25, 'availability': .20, 'distance': .15, 'speed': .15, 'price': .10, 'rating': .10, 'battery': .05}

def _clamp(value):
    return max(0.0, min(100.0, float(value)))

def _rating_score(station):
    rating = station.get('rating')
    if rating is None:
        return None
    reviews = max(0, int(station.get('review_count') or 0))
    return _clamp(((float(rating) * reviews + 3.5 * 10) / (reviews + 10)) / 5 * 100)

def _availability_score(station):
    available, total = station.get('available_connectors'), station.get('total_connectors')
    if available is None or not total or total <= 0:
        return None
    if station.get('availability_fresh') is False:
        return 35.0
    return _clamp(available / total * 100)

def score_station(station, user_lat=17.4065, user_lng=78.4772, preferences=None):
    preferences = preferences or {}
    distance = float(station.get('distance_km') or inf)
    power = float(station.get('charging_power_kw') or 0)
    max_power = float(preferences.get('vehicle_max_power_kw') or power)
    price = station.get('price_per_kwh')
    factors = {
        'compatibility': 100.0,
        'availability': _availability_score(station),
        'distance': _clamp(100 - distance * 8),
        'speed': _clamp(min(power, max_power) / 150 * 100),
        'price': None if price is None else _clamp(100 - float(price) * 5),
        'rating': _rating_score(station),
        'battery': preferences.get('battery_suitability'),
    }
    used = sum(WEIGHTS[key] for key, value in factors.items() if value is not None)
    return sum(WEIGHTS[key] * value for key, value in factors.items() if value is not None) / used if used else 0.0

def recommended_stations(stations, user_lat=17.4065, user_lng=78.4772, preferences=None):
    preferences = preferences or {}
    required = {str(value).lower() for value in preferences.get('required_connectors', [])}
    battery_range = preferences.get('estimated_range_km')
    reserve = float(preferences.get('reserve_percent', 15)) / 100
    valid = []
    for station in stations:
        if str(station.get('status', '')).upper() in {'MAINTENANCE', 'CLOSED'}:
            continue
        connectors = {str(value.get('connector_type', value)).lower() for value in station.get('connectors', [])}
        if required and not required.intersection(connectors):
            continue
        if battery_range is not None and float(station.get('distance_km') or inf) > float(battery_range) * (1 - reserve):
            continue
        station['ranking_score'] = round(score_station(station, user_lat, user_lng, preferences), 2)
        valid.append(station)
    return sorted(valid, key=lambda item: (-item['ranking_score'], str(item.get('id', ''))))
