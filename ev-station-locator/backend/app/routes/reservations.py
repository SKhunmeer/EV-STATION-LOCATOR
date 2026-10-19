from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app import db
from app.models import Reservation
from app.services.reservation_service import ReservationService

reservations_bp = Blueprint('reservations', __name__)


@reservations_bp.post('/')
@jwt_required()
def create_reservation():
    payload = request.get_json() or {}
    try:
        reservation = ReservationService.create_reservation(int(get_jwt_identity()), payload)
        return jsonify(reservation.to_dict()), 201
    except Exception as exc:
        return jsonify({'error': str(exc)}), 400


@reservations_bp.get('/')
@jwt_required()
def list_reservations():
    reservations = ReservationService.list_user_reservations(int(get_jwt_identity()))
    return jsonify([r.to_dict() for r in reservations]), 200


@reservations_bp.get('/<int:reservation_id>')
@jwt_required()
def get_reservation(reservation_id):
    reservation = Reservation.query.filter_by(id=reservation_id, user_id=int(get_jwt_identity())).first_or_404()
    return jsonify(reservation.to_dict()), 200


@reservations_bp.delete('/<int:reservation_id>')
@jwt_required()
def cancel_reservation(reservation_id):
    try:
        reservation = ReservationService.cancel_reservation(reservation_id, int(get_jwt_identity()))
        return jsonify({'message': 'Reservation cancelled successfully', 'reservation': reservation.to_dict()}), 200
    except Exception as exc:
        return jsonify({'error': str(exc)}), 400
