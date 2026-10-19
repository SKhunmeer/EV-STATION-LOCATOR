from flask_jwt_extended import create_access_token

from app.models import User


class AuthService:
    @staticmethod
    def register_user(data):
        if User.query.filter_by(email=data['email'].lower()).first():
            raise ValueError('Email already exists')
        user = User(
            name=data['name'],
            email=data['email'].lower(),
            ev_model=data.get('ev_model', 'EV'),
            battery_capacity_kwh=data.get('battery_capacity_kwh', 40.0),
            efficiency_km_per_kwh=data.get('efficiency_km_per_kwh', 6.0),
        )
        user.set_password(data['password'])
        return user

    @staticmethod
    def login_user(email, password):
        user = User.query.filter_by(email=email.lower()).first()
        if not user or not user.check_password(password):
            raise ValueError('Invalid email or password')
        token = create_access_token(identity=str(user.id))
        return user, token
