import os
from datetime import timedelta

from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_sqlalchemy import SQLAlchemy
from dotenv import load_dotenv

load_dotenv()

db = SQLAlchemy()


def create_app(test_config=None):
    app = Flask(__name__)
    app.config.update({
        'SQLALCHEMY_DATABASE_URI': os.getenv('DATABASE_URL') or 'sqlite:///ev_station_locator.db',
        'SQLALCHEMY_TRACK_MODIFICATIONS': False,
        'JWT_SECRET_KEY': os.getenv('JWT_SECRET_KEY', 'dev-secret-jwt'),
        'JWT_ACCESS_TOKEN_EXPIRES': timedelta(hours=12),
        'SECRET_KEY': os.getenv('SECRET_KEY', 'dev-secret'),
        'CORS_HEADERS': 'Content-Type',
    })
    if test_config:
        app.config.update(test_config)

    CORS(app, resources={r"/api/*": {"origins": os.getenv('CORS_ORIGINS', '*').split(',')}}, supports_credentials=True)
    db.init_app(app)
    JWTManager(app)

    from app.routes.auth import auth_bp
    from app.routes.stations import stations_bp
    from app.routes.providers import providers_bp
    from app.routes.reservations import reservations_bp
    from app.routes.trips import trips_bp
    from app.routes.users import users_bp

    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(stations_bp, url_prefix='/api/stations')
    app.register_blueprint(providers_bp, url_prefix='/api/providers')
    app.register_blueprint(reservations_bp, url_prefix='/api/reservations')
    app.register_blueprint(trips_bp, url_prefix='/api/trips')
    app.register_blueprint(users_bp, url_prefix='/api/users')

    with app.app_context():
        from app.models.user import User
        from app.models.provider import Provider
        from app.models.charging_station import ChargingStation
        from app.models.connector import Connector
        from app.models.reservation import Reservation
        from app.models.trip import Trip
        from app.models.trip_stop import TripStop

    @app.get('/')
    def health_check():
        return {'status': 'ok', 'message': 'EV Station Locator API is running'}, 200

    return app
