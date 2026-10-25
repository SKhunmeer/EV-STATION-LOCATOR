from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.models import Trip, User
from app.services.trip_service import TripService

trips_bp = Blueprint('trips', __name__)


@trips_bp.post('/plan')
@jwt_required()
def plan_trip():
    payload = request.get_json() or {}
    user = User.query.get_or_404(int(get_jwt_identity()))
    try:
        trip = TripService.plan_trip(user, payload)
        return jsonify(trip.to_dict()), 200
    except (TypeError, ValueError) as exc:
        return jsonify({'error': str(exc)}), 400


@trips_bp.get('/')
@jwt_required()
def list_trips():
    user = User.query.get_or_404(int(get_jwt_identity()))
    return jsonify([trip.to_dict() for trip in user.trips]), 200


@trips_bp.get('/<int:trip_id>')
@jwt_required()
def get_trip(trip_id):
    trip = Trip.query.filter_by(id=trip_id, user_id=int(get_jwt_identity())).first_or_404()
    return jsonify(trip.to_dict()), 200
