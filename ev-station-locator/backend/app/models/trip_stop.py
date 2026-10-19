from app import db


class TripStop(db.Model):
    __tablename__ = 'trip_stops'

    id = db.Column(db.Integer, primary_key=True)
    trip_id = db.Column(db.Integer, db.ForeignKey('trips.id'), nullable=False)
    station_id = db.Column(db.Integer, db.ForeignKey('charging_stations.id'), nullable=False)
    arrival_soc = db.Column(db.Float, nullable=False)
    target_soc = db.Column(db.Float, nullable=False)
    charging_time_minutes = db.Column(db.Float, nullable=False)
    charging_cost = db.Column(db.Float, nullable=False)

    trip = db.relationship('Trip', back_populates='stops')
    station = db.relationship('ChargingStation', back_populates='trip_stops')

    def to_dict(self):
        return {
            'id': self.id,
            'trip_id': self.trip_id,
            'station_id': self.station_id,
            'station_name': self.station.name if self.station else None,
            'arrival_soc': self.arrival_soc,
            'target_soc': self.target_soc,
            'charging_time_minutes': self.charging_time_minutes,
            'charging_cost': self.charging_cost,
        }
