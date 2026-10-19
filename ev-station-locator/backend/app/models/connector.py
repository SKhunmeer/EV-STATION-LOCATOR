from datetime import datetime

from app import db


class Connector(db.Model):
    __tablename__ = 'connectors'

    id = db.Column(db.Integer, primary_key=True)
    station_id = db.Column(db.Integer, db.ForeignKey('charging_stations.id'), nullable=False)
    connector_type = db.Column(db.String(40), nullable=False)
    power_kw = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(30), nullable=False, default='AVAILABLE')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    station = db.relationship('ChargingStation', back_populates='connectors')
    reservations = db.relationship('Reservation', back_populates='connector', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'station_id': self.station_id,
            'connector_type': self.connector_type,
            'power_kw': self.power_kw,
            'status': self.status,
        }
