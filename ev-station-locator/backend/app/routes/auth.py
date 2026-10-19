from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app import db
from app.models import User
from app.schemas.user_schema import UserLoginSchema, UserRegistrationSchema
from app.services.auth_service import AuthService

auth_bp = Blueprint('auth', __name__)


@auth_bp.post('/register')
def register():
    data = request.get_json() or {}
    try:
        validated = UserRegistrationSchema().load(data)
        user = AuthService.register_user(validated)
        db.session.add(user)
        db.session.commit()
        return jsonify({'message': 'User registered successfully', 'user': user.to_dict()}), 201
    except Exception as exc:
        return jsonify({'error': str(exc)}), 400


@auth_bp.post('/login')
def login():
    data = request.get_json() or {}
    try:
        validated = UserLoginSchema().load(data)
        user, token = AuthService.login_user(validated['email'], validated['password'])
        return jsonify({'token': token, 'user': user.to_dict()}), 200
    except Exception as exc:
        return jsonify({'error': str(exc)}), 401


@auth_bp.get('/me')
@jwt_required()
def me():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    return jsonify(user.to_dict()), 200
