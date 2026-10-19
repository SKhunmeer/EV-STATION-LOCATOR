# EV Station Locator & Smart EV Trip Planner

Chargewise is an Android-first Flutter EV station locator with a Flask API adapter, transparent recommendations, and explicit data-confidence states. The repository does not include the referenced EV Station Locator PDF/PPT; the implementation follows the supplied build specification.

See [REQUIREMENTS_AUDIT.md](./REQUIREMENTS_AUDIT.md) for a requirement-by-requirement implementation and verification status. Choice history now makes bounded, explainable distance/speed/price adjustments after three or more recorded choices when Firebase is configured.

## Project Overview

The application normalizes provider station records into a unified schema and provides a user-friendly mobile app for searching, comparing, recommending, and navigating to stations. Legacy seeded provider tables remain available only for explicit local demo mode.

Provider note: Open Charge Map is the live station source when `OCM_API_KEY` is configured. OCM POI records do not prove real-time connector occupancy, so availability is shown as unknown/stale rather than fabricated. Seeded demo data is disabled unless `ALLOW_DEMO_DATA=true`.

## Features

- Flutter Android mobile app with Material 3 UI
- Flask REST API with SQLAlchemy ORM
- PostgreSQL database with Alembic migrations
- JWT authentication
- Open Charge Map provider adapter with external station IDs and normalized connector records
- Availability freshness and unknown-state handling
- Reservation creation with conflict prevention
- Smart charging station recommendation
- EV trip planning with charging stop suggestions
- Docker support
- APK build instructions

## Architecture

Frontend: Flutter
Backend: Flask + SQLAlchemy + Flask-JWT-Extended
Database: PostgreSQL
Deployment: Render / Gunicorn / PostgreSQL

## Local Setup

### Backend

1. cd backend
2. python3 -m venv .venv
3. source .venv/bin/activate
4. pip install -r requirements.txt
5. Create PostgreSQL database: evstation
6. cp .env.example .env
7. Update DATABASE_URL and JWT secret values
8. flask db upgrade (if using Alembic set up) or run `python seed.py`
9. flask run

### Flutter

1. cd frontend
2. flutter pub get
3. Update API base URL in lib/core/constants/app_constants.dart (or equivalent)
4. flutter run

## Docker

```bash
docker compose up --build
```

## Backend Deployment

Deploy the backend to Render or another hosting provider using the provided Dockerfile and Gunicorn command.

## APK Generation

```bash
cd frontend
flutter build apk --release
```

The APK is generated under `build/app/outputs/flutter-apk/app-release.apk`.

## Demo Scenarios

- Provider aggregation across multiple stations
- Ghost station simulation via maintenance status
- Live status switching between available and occupied
- Reservation conflict prevention
- Smart recommendation after a busy nearby station
- Trip planning from Hyderabad to Bengaluru

## Future Improvements

- Network-specific live occupancy requires a provider API that exposes connector status; OCM alone does not.
- Firebase/Google Maps configuration is intentionally external and no secrets are committed.

## Configuration

1. Copy `backend/.env.example` to `backend/.env` and add an Open Charge Map API key.
2. Add `google-services.json` from Firebase to `frontend/android/app/` and enable Email/Password Authentication and Firestore.
3. Replace `GOOGLE_MAPS_API_KEY` in `frontend/android/app/src/main/res/values/google_maps.xml` with a restricted Android Maps key. Enable Maps SDK for Android and Directions/Routes services if used.
4. Run the Flutter app with `--dart-define=API_BASE_URL=http://10.0.2.2:5000/api` on the Android emulator. Use the host LAN address on a physical device.

## Ranking and data policy

The Dart service in `frontend/lib/core/ranking.dart` uses weights compatibility 25%, availability 20%, distance 15%, charging speed 15%, price 10%, rating 10%, and battery suitability 5%. Missing values are removed from the denominator; stale availability scores 35 rather than 100; ratings use a ten-review confidence prior. Connector incompatibility and insufficient estimated range exclude a station. Ties use the external station ID.

Congestion is only calculated when fresh comparable occupied/total connector data exists. Open Charge Map currently supplies site records rather than live occupancy, so the UI says “Availability unknown” and never invents congestion.

## Verification

Run `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` from `frontend/`. The ranking tests cover compatibility, reachability, missing values, stale availability, confidence, and deterministic ordering. Firebase authentication, Firestore persistence, Google Maps tiles, and live OCM results require the external configuration above.

## Folder Structure

```text
ev-station-locator/
├── backend/
│   ├── app/
│   ├── migrations/
│   ├── .env.example
│   ├── Dockerfile
│   ├── Procfile
│   ├── requirements.txt
│   └── seed.py
├── frontend/
│   └── Flutter app
├── docker-compose.yml
├── README.md
└── .gitignore
```
