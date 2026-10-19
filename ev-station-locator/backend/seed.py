from datetime import datetime

from app import create_app, db
from app.models import ChargingStation, Connector, Provider, User

PROVIDERS = [
    {'name': 'Tata Power', 'description': 'Fast charging network across metro corridors', 'logo_url': ''},
    {'name': 'ChargeZone', 'description': 'Urban charging convenience', 'logo_url': ''},
    {'name': 'Zeon', 'description': 'High-power station network', 'logo_url': ''},
    {'name': 'Statiq', 'description': 'Destination and highway charging', 'logo_url': ''},
    {'name': 'Jio-bp', 'description': 'Digital-first EV charging', 'logo_url': ''},
]

STATIONS = [
    {'name': 'ChargeZone Gachibowli', 'provider': 'ChargeZone', 'latitude': 17.4401, 'longitude': 78.3814, 'address': 'Gachibowli Rd', 'city': 'Hyderabad', 'charging_power_kw': 60, 'price_per_kwh': 16.0, 'status': 'AVAILABLE', 'opening_hours': '24/7'},
    {'name': 'Tata Power Kondapur', 'provider': 'Tata Power', 'latitude': 17.4540, 'longitude': 78.3735, 'address': 'Kondapur', 'city': 'Hyderabad', 'charging_power_kw': 50, 'price_per_kwh': 17.0, 'status': 'AVAILABLE', 'opening_hours': '24/7'},
    {'name': 'Zeon Banjara Hills', 'provider': 'Zeon', 'latitude': 17.4140, 'longitude': 78.4260, 'address': 'Banjara Hills', 'city': 'Hyderabad', 'charging_power_kw': 80, 'price_per_kwh': 18.5, 'status': 'OCCUPIED', 'opening_hours': '06:00-23:00'},
    {'name': 'Statiq Madhapur', 'provider': 'Statiq', 'latitude': 17.4418, 'longitude': 78.3904, 'address': 'Madhapur', 'city': 'Hyderabad', 'charging_power_kw': 120, 'price_per_kwh': 19.0, 'status': 'AVAILABLE', 'opening_hours': '24/7'},
    {'name': 'Jio-bp Hitech City', 'provider': 'Jio-bp', 'latitude': 17.4511, 'longitude': 78.3856, 'address': 'Hitech City', 'city': 'Hyderabad', 'charging_power_kw': 90, 'price_per_kwh': 15.5, 'status': 'AVAILABLE', 'opening_hours': '24/7'},
    {'name': 'Tata Power Shamshabad', 'provider': 'Tata Power', 'latitude': 17.2383, 'longitude': 78.4291, 'address': 'Airport Road', 'city': 'Hyderabad', 'charging_power_kw': 60, 'price_per_kwh': 14.5, 'status': 'AVAILABLE', 'opening_hours': '24/7'},
    {'name': 'ChargeZone Kukatpally', 'provider': 'ChargeZone', 'latitude': 17.4948, 'longitude': 78.3983, 'address': 'Kukatpally', 'city': 'Hyderabad', 'charging_power_kw': 50, 'price_per_kwh': 16.0, 'status': 'MAINTENANCE', 'opening_hours': '08:00-20:00'},
    {'name': 'Zeon Ameerpet', 'provider': 'Zeon', 'latitude': 17.4351, 'longitude': 78.4484, 'address': 'Ameerpet', 'city': 'Hyderabad', 'charging_power_kw': 50, 'price_per_kwh': 17.5, 'status': 'AVAILABLE', 'opening_hours': '24/7'},
    {'name': 'Statiq ORR', 'provider': 'Statiq', 'latitude': 17.3822, 'longitude': 78.4738, 'address': 'Outer Ring Rd', 'city': 'Hyderabad', 'charging_power_kw': 150, 'price_per_kwh': 20.0, 'status': 'AVAILABLE', 'opening_hours': '24/7'},
    {'name': 'Jio-bp Secunderabad', 'provider': 'Jio-bp', 'latitude': 17.4399, 'longitude': 78.4984, 'address': 'Secunderabad', 'city': 'Hyderabad', 'charging_power_kw': 60, 'price_per_kwh': 15.0, 'status': 'OCCUPIED', 'opening_hours': '06:00-23:00'},
]

CONNECTOR_TYPES = ['CCS2', 'Type 2', 'CHAdeMO', 'AC DC']


def seed_database():
    app = create_app()
    with app.app_context():
        db.drop_all()
        db.create_all()

        for provider_data in PROVIDERS:
            provider = Provider(**provider_data)
            db.session.add(provider)
        db.session.commit()

        providers = {provider.name: provider for provider in Provider.query.all()}

        for index, station_data in enumerate(STATIONS, start=1):
            station = ChargingStation(
                provider_id=providers[station_data['provider']].id,
                name=station_data['name'],
                latitude=station_data['latitude'],
                longitude=station_data['longitude'],
                address=station_data['address'],
                city=station_data['city'],
                charging_power_kw=station_data['charging_power_kw'],
                price_per_kwh=station_data['price_per_kwh'],
                total_connectors=4,
                status=station_data['status'],
                opening_hours=station_data['opening_hours'],
            )
            db.session.add(station)
            db.session.flush()

            for i in range(4):
                status = 'AVAILABLE'
                if station_data['status'] == 'MAINTENANCE' and i == 0:
                    status = 'MAINTENANCE'
                elif station_data['status'] == 'OCCUPIED' and i in (0, 1):
                    status = 'OCCUPIED'
                db.session.add(Connector(station_id=station.id, connector_type=CONNECTOR_TYPES[i % len(CONNECTOR_TYPES)], power_kw=60 + i * 20, status=status))

        if not User.query.filter_by(email='demo@evstation.app').first():
            user = User(name='Demo User', email='demo@evstation.app', ev_model='MG ZS EV', battery_capacity_kwh=50.0, efficiency_km_per_kwh=6.0)
            user.set_password('demo123')
            db.session.add(user)

        db.session.commit()
        print('Database seeded with 5 providers and 10 stations.')


if __name__ == '__main__':
    seed_database()
