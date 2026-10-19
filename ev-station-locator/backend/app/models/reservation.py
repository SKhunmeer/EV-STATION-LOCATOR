from datetime import datetime

from app import db


class Reservation(db.Model):
    __tablename__ = 'reservations'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    station_id = db.Column(db.Integer, db.ForeignKey('charging_stations.id'), nullable=False)
    connector_id = db.Column(db.Integer, db.ForeignKey('connectors.id'), nullable=False)
    reservation_date = db.Column(db.Date, nullable=False)
    start_time = db.Column(db.Time, nullable=False)
    end_time = db.Column(db.Time, nullable=False)
    status = db.Column(db.String(30), nullable=False, default='UPCOMING')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', back_populates='reservations')
    station = db.relationship('ChargingStation', back_populates='reservations')
    connector = db.relationship('Connector', back_populates='reservations')

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'station_id': self.station_id,
            'station_name': self.station.name if self.station else None,
            'connector_id': self.connector_id,
            'connector_type': self.connector.connector_type if self.connector else None,
            'reservation_date': self.reservation_date.isoformat(),
            'start_time': self.start_time.strftime('%H:%M'),
            'end_time': self.end_time.strftime('%H:%M'),
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
