from app import db
from app.models import ChargingStation, Trip, TripStop


class TripService:
    @staticmethod
    def plan_trip(user, payload):
        start_location = payload.get('start_location', 'Hyderabad')
        destination = payload.get('destination', 'Bengaluru')
        initial_soc = float(payload.get('initial_soc', 30))
        if not 0 <= initial_soc <= 100:
            raise ValueError('initial_soc must be between 0 and 100')
        battery_capacity = float(payload.get('battery_capacity_kwh', user.battery_capacity_kwh or 40))
        efficiency = float(payload.get('efficiency_km_per_kwh', user.efficiency_km_per_kwh or 6))
        if battery_capacity <= 0 or efficiency <= 0:
            raise ValueError('Battery capacity and efficiency must be positive')
        available_energy = battery_capacity * (initial_soc / 100)
        estimated_range = available_energy * efficiency

        stations = ChargingStation.query.filter_by(status='AVAILABLE').all()
        stations = [station for station in stations if station.price_per_kwh is not None]
        chosen = stations[:3]
        trip = Trip(
            user_id=user.id,
            start_location=start_location,
            destination=destination,
            initial_soc=initial_soc,
            estimated_distance=estimated_range,
            estimated_time='4h 30m',
            estimated_cost=0.0,
        )
        for station in chosen:
            trip.stops.append(TripStop(
                station_id=station.id,
                arrival_soc=max(10, initial_soc - 10),
                target_soc=75.0,
                charging_time_minutes=25.0,
                charging_cost=station.price_per_kwh * 15,
            ))
        db.session.add(trip)
        db.session.commit()
        return trip
