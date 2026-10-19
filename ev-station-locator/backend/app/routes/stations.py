from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required

from app import db
from app.algorithms.recommendation import recommended_stations
from app.models import ChargingStation, Connector, Provider
from app.schemas.station_schema import ReservationSchema, StationQuerySchema
from app.services.station_service import StationService

stations_bp = Blueprint('stations', __name__)


@stations_bp.get('/')
def list_stations():
    stations = StationService.search_stations(request.args.get('q', ''))
    return jsonify(stations), 200


@stations_bp.get('/nearby')
def nearby_stations():
    lat = float(request.args.get('lat', 17.4065))
    lng = float(request.args.get('lng', 78.4772))
    radius = float(request.args.get('radius_km', 15.0))
    return jsonify(StationService.nearby_stations(lat=lat, lng=lng, radius_km=radius)), 200


@stations_bp.get('/search')
def search_stations():
    query = request.args.get('q', '')
    return jsonify(StationService.search_stations(query)), 200


@stations_bp.get('/filter')
def filter_stations():
    params = request.args.to_dict()
    return jsonify(StationService.filter_stations(**params)), 200


@stations_bp.get('/live-status')
def live_status():
    return jsonify(StationService.get_live_status()), 200


@stations_bp.get('/recommended')
def recommended():
    lat = float(request.args.get('lat', 17.4065))
    lng = float(request.args.get('lng', 78.4772))
    stations = StationService.nearby_stations(lat=lat, lng=lng, radius_km=float(request.args.get('radius_km', 50)))
    preferences = {
        'max_price': float(request.args['max_price']) if request.args.get('max_price') else None,
        'min_power': float(request.args['min_power']) if request.args.get('min_power') else None,
        'fast_only': request.args.get('fast_only', '').lower() == 'true',
    }
    stations = [station for station in stations
                if (preferences['max_price'] is None or (station.get('price_per_kwh') is not None and station['price_per_kwh'] <= preferences['max_price']))
                and (preferences['min_power'] is None or (station.get('charging_power_kw') or 0) >= preferences['min_power'])
                and (not preferences['fast_only'] or (station.get('charging_power_kw') or 0) >= 50)]
    return jsonify(recommended_stations(stations, user_lat=lat, user_lng=lng, preferences=preferences)), 200


@stations_bp.get('/<int:station_id>')
def get_station(station_id):
    station = StationService.get_station_by_id(station_id)
    return jsonify(station.to_dict(include_connectors=True)), 200


@stations_bp.get('/<int:station_id>/connectors')
def station_connectors(station_id):
    station = StationService.get_station_by_id(station_id)
    return jsonify([c.to_dict() for c in station.connectors]), 200
