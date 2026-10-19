import json

import pytest

from app import create_app, db


@pytest.fixture()
def app():
    app = create_app({
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:',
        'JWT_SECRET_KEY': 'test-secret',
    })
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


@pytest.fixture()
def client(app):
    return app.test_client()


def test_register_and_login(client):
    response = client.post('/api/auth/register', json={
        'name': 'Test User',
        'email': 'test@example.com',
        'password': 'secret123',
        'ev_model': 'MG ZS EV',
        'battery_capacity_kwh': 50,
        'efficiency_km_per_kwh': 6,
    })
    assert response.status_code == 201
    login_response = client.post('/api/auth/login', json={
        'email': 'test@example.com',
        'password': 'secret123',
    })
    assert login_response.status_code == 200
    data = login_response.get_json()
    assert 'token' in data


def test_station_listing(client):
    from app.models import Provider, ChargingStation, Connector

    provider = Provider(name='TestProvider', description='demo')
    db.session.add(provider)
    db.session.commit()
    station = ChargingStation(provider_id=provider.id, name='Alpha Station', latitude=17.4, longitude=78.4, address='Road', city='Hyderabad', charging_power_kw=60, price_per_kwh=16.0, total_connectors=1, status='AVAILABLE')
    db.session.add(station)
    db.session.flush()
    db.session.add(Connector(station_id=station.id, connector_type='CCS2', power_kw=60, status='AVAILABLE'))
    db.session.commit()

    response = client.get('/api/stations/')
    assert response.status_code == 200
    payload = response.get_json()
    assert len(payload) >= 1


def test_recommendations_prioritize_available_stations(client):
    from app.models import ChargingStation, Connector, Provider

    provider = Provider(name='RecommendationProvider', description='demo')
    db.session.add(provider)
    db.session.commit()
    available = ChargingStation(provider_id=provider.id, name='Fast Available', latitude=17.4065, longitude=78.4772, city='Hyderabad', charging_power_kw=120, price_per_kwh=15.0, total_connectors=1, status='AVAILABLE')
    maintenance = ChargingStation(provider_id=provider.id, name='Unavailable', latitude=17.4065, longitude=78.4772, city='Hyderabad', charging_power_kw=150, price_per_kwh=10.0, total_connectors=1, status='MAINTENANCE')
    db.session.add_all([available, maintenance])
    db.session.flush()
    db.session.add(Connector(station_id=available.id, connector_type='CCS2', power_kw=120, status='AVAILABLE'))
    db.session.add(Connector(station_id=maintenance.id, connector_type='CCS2', power_kw=150, status='MAINTENANCE'))
    db.session.commit()

    response = client.get('/api/stations/recommended')
    assert response.status_code == 200
    payload = response.get_json()
    assert payload[0]['name'] == 'Fast Available'
    assert all(station['status'] != 'MAINTENANCE' for station in payload)


def test_trip_planning_requires_auth(client):
    response = client.post('/api/trips/plan', json={'start_location': 'Hyderabad', 'destination': 'Bengaluru', 'initial_soc': 30})
    assert response.status_code == 401


def test_authenticated_trip_planning_persists_trip_and_stops(client):
    client.post('/api/auth/register', json={
        'name': 'Trip User',
        'email': 'trip@example.com',
        'password': 'secret123',
        'battery_capacity_kwh': 50,
        'efficiency_km_per_kwh': 6,
    })
    login_response = client.post('/api/auth/login', json={
        'email': 'trip@example.com',
        'password': 'secret123',
    })
    token = login_response.get_json()['token']

    from app.models import ChargingStation, Connector, Provider

    provider = Provider(name='TripProvider', description='demo')
    db.session.add(provider)
    db.session.commit()
    station = ChargingStation(
        provider_id=provider.id,
        name='Trip Station',
        latitude=17.4,
        longitude=78.4,
        address='Road',
        city='Hyderabad',
        charging_power_kw=60,
        price_per_kwh=16.0,
        total_connectors=1,
        status='AVAILABLE',
    )
    db.session.add(station)
    db.session.flush()
    db.session.add(Connector(station_id=station.id, connector_type='CCS2', power_kw=60, status='AVAILABLE'))
    db.session.commit()

    headers = {'Authorization': f'Bearer {token}'}
    response = client.post('/api/trips/plan', headers=headers, json={
        'start_location': 'Hyderabad',
        'destination': 'Bengaluru',
        'initial_soc': 80,
    })
    assert response.status_code == 200
    trip = response.get_json()
    assert trip['id'] is not None
    assert len(trip['stops']) == 1

    fetched = client.get(f"/api/trips/{trip['id']}", headers=headers)
    assert fetched.status_code == 200
    assert fetched.get_json()['stops'][0]['station_name'] == 'Trip Station'
