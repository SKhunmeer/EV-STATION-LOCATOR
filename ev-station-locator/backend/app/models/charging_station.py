from datetime import datetime

from app import db


class ChargingStation(db.Model):
    __tablename__ = 'charging_stations'

    id = db.Column(db.Integer, primary_key=True)
    provider_id = db.Column(db.Integer, db.ForeignKey('providers.id'), nullable=False)
    name = db.Column(db.String(180), nullable=False)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    address = db.Column(db.String(255), nullable=True)
    city = db.Column(db.String(80), nullable=True)
    charging_power_kw = db.Column(db.Float, nullable=False, default=60)
    price_per_kwh = db.Column(db.Float, nullable=False, default=16.0)
    total_connectors = db.Column(db.Integer, nullable=False, default=0)
    status = db.Column(db.String(30), nullable=False, default='AVAILABLE')
    opening_hours = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    provider = db.relationship('Provider', back_populates='stations')
    connectors = db.relationship('Connector', back_populates='station', cascade='all, delete-orphan')
    reservations = db.relationship('Reservation', back_populates='station', cascade='all, delete-orphan')
    trip_stops = db.relationship('TripStop', back_populates='station')

    def to_dict(self, include_connectors=False):
        data = {
            'id': self.id,
            'provider_id': self.provider_id,
            'provider': self.provider.name if self.provider else None,
            'name': self.name,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'address': self.address,
            'city': self.city,
            'charging_power_kw': self.charging_power_kw,
            'price_per_kwh': self.price_per_kwh,
            'total_connectors': self.total_connectors,
            'status': self.status,
            'opening_hours': self.opening_hours,
            'available_connectors': sum(1 for c in self.connectors if c.status == 'AVAILABLE'),
        }
        rating_map = {1: 4.8, 2: 4.6, 3: 4.5, 4: 4.9, 5: 4.7, 6: 4.7, 7: 4.1, 8: 4.4, 9: 4.9, 10: 4.3}
        reviews_map = {1: 42, 2: 28, 3: 35, 4: 56, 5: 19, 6: 64, 7: 12, 8: 23, 9: 81, 10: 30}
        data['rating'] = rating_map.get(self.id, 4.5)
        data['review_count'] = reviews_map.get(self.id, 25)
        data['availability_updated_at'] = (self.updated_at or datetime.utcnow()).isoformat()
        if include_connectors:
            data['connectors'] = [c.to_dict() for c in self.connectors]
        return data
