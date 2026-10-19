from datetime import datetime

from app import db


class Trip(db.Model):
    __tablename__ = 'trips'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    start_location = db.Column(db.String(150), nullable=False)
    destination = db.Column(db.String(150), nullable=False)
    initial_soc = db.Column(db.Float, nullable=False)
    estimated_distance = db.Column(db.Float, nullable=False)
    estimated_time = db.Column(db.String(60), nullable=True)
    estimated_cost = db.Column(db.Float, nullable=False, default=0.0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', back_populates='trips')
    stops = db.relationship('TripStop', back_populates='trip', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'start_location': self.start_location,
            'destination': self.destination,
            'initial_soc': self.initial_soc,
            'estimated_distance': self.estimated_distance,
            'estimated_time': self.estimated_time,
            'estimated_cost': self.estimated_cost,
            'stops': [s.to_dict() for s in self.stops],
        }
