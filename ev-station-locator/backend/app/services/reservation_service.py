from datetime import datetime

from app import db
from app.models import Connector, Reservation


class ReservationService:
    @staticmethod
    def create_reservation(user_id, payload):
        required = ('station_id', 'connector_id', 'reservation_date', 'start_time', 'end_time')
        missing = [field for field in required if field not in payload]
        if missing:
            raise ValueError(f'Missing reservation fields: {", ".join(missing)}')
        try:
            station_id = int(payload['station_id'])
            connector_id = int(payload['connector_id'])
            reservation_date = datetime.strptime(payload['reservation_date'], '%Y-%m-%d').date()
            start_time = datetime.strptime(payload['start_time'], '%H:%M').time()
            end_time = datetime.strptime(payload['end_time'], '%H:%M').time()
        except (TypeError, ValueError):
            raise ValueError('Use station/connector IDs, YYYY-MM-DD, and HH:MM time values')
        if end_time <= start_time:
            raise ValueError('Reservation end time must be after start time')

        connector = Connector.query.get_or_404(connector_id)
        if connector.station_id != station_id:
            raise ValueError('Connector does not belong to the selected station')
        if connector.status != 'AVAILABLE':
            raise ValueError('This connector is not currently available for reservation')

        conflict = Reservation.query.filter(
            Reservation.connector_id == connector_id,
            Reservation.reservation_date == reservation_date,
            Reservation.status.in_(['UPCOMING', 'ACTIVE']),
            Reservation.start_time < end_time,
            Reservation.end_time > start_time,
        ).first()
        if conflict:
            raise ValueError('This connector is already booked for the requested time')

        reservation = Reservation(
            user_id=user_id,
            station_id=station_id,
            connector_id=connector_id,
            reservation_date=reservation_date,
            start_time=start_time,
            end_time=end_time,
            status='UPCOMING',
        )
        db.session.add(reservation)
        db.session.commit()
        return reservation

    @staticmethod
    def list_user_reservations(user_id):
        return Reservation.query.filter_by(user_id=user_id).order_by(Reservation.reservation_date.desc(), Reservation.start_time.desc()).all()

    @staticmethod
    def cancel_reservation(reservation_id, user_id):
        reservation = Reservation.query.filter_by(id=reservation_id, user_id=user_id).first_or_404()
        reservation.status = 'CANCELLED'
        db.session.commit()
        return reservation
