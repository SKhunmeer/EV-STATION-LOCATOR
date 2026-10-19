from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

from app import db


class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    ev_model = db.Column(db.String(120), nullable=True)
    battery_capacity_kwh = db.Column(db.Float, nullable=True)
    efficiency_km_per_kwh = db.Column(db.Float, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    reservations = db.relationship('Reservation', back_populates='user', cascade='all, delete-orphan')
    trips = db.relationship('Trip', back_populates='user', cascade='all, delete-orphan')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'ev_model': self.ev_model,
            'battery_capacity_kwh': self.battery_capacity_kwh,
            'efficiency_km_per_kwh': self.efficiency_km_per_kwh,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
