from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.models import User

users_bp = Blueprint('users', __name__)


@users_bp.get('/me')
@jwt_required()
def get_me():
    user = User.query.get_or_404(int(get_jwt_identity()))
    return jsonify(user.to_dict()), 200


@users_bp.put('/me')
@jwt_required()
def update_me():
    user = User.query.get_or_404(int(get_jwt_identity()))
    payload = request.get_json() or {}
    if 'name' in payload:
        user.name = payload['name']
    if 'ev_model' in payload:
        user.ev_model = payload['ev_model']
    if 'battery_capacity_kwh' in payload:
        user.battery_capacity_kwh = float(payload['battery_capacity_kwh'])
    if 'efficiency_km_per_kwh' in payload:
        user.efficiency_km_per_kwh = float(payload['efficiency_km_per_kwh'])
    from app import db
    db.session.commit()
    return jsonify(user.to_dict()), 200
