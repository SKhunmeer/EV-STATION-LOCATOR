# EV Station Locator requirement audit

Status labels: **implemented in source**, **configuration-dependent**, or **not verified here**.

| Requirement | Evidence / status |
|---|---|
| Flutter Android presentation | Implemented in `frontend/lib/main.dart`; Android permissions and Google Maps metadata are in the Android project. Build not verified because the local Flutter toolchain is blocked by the host macOS developer-tool configuration. |
| Provider state management | Implemented through `StationStore extends ChangeNotifier` and `ChangeNotifierProvider`. |
| Firebase Authentication | Email/password registration, login, sign-out, and persistence path are implemented. Requires Firebase Android configuration and enabled Email/Password provider. Not externally verified here. |
| Cloud Firestore D1-D4 | `FirestoreRepository` implements users/vehicles, favourites, choice history, and per-user reviews. Firestore rules enforce user ownership and rating validation. Aggregate rating materialization is not implemented; provider/application ratings remain read-only input. |
| Live map and location | `GoogleMap`, real station coordinates, location permission handling, markers, and explicit degraded states are implemented. Requires restricted Maps key and device/emulator permission. |
| Real station data | Backend calls Open Charge Map when `OCM_API_KEY` is configured. Seeded demo data is disabled by default. Provider access was not verified here because no key was available. |
| Availability and congestion | OCM records are mapped to `UNKNOWN`; no availability or congestion percentage is invented. Live occupancy can be added only from a provider with fresh occupied/total connector data. |
| Search and filters | Search, connector, distance, minimum power, and confirmed-availability filters are functional in the Provider store. Price/opening-hours/minimum-rating filters need provider fields before they can safely match. |
| Comparison | At least two stations can be selected and compared side by side for distance, compatibility, power, availability, price, and rating. |
| Seven-factor ranking | Implemented in `frontend/lib/core/ranking.dart` and `backend/app/algorithms/recommendation.py`. Weights are compatibility 25%, availability 20%, distance 15%, speed 15%, price 10%, rating 10%, battery suitability 5%. Missing data is excluded from the denominator; stale availability is discounted; ties use station ID. |
| Compatibility and reachability | Connector mismatch and insufficient estimated remaining range are hard exclusions when vehicle context is present. |
| Explainability | Recommendation cards show score and the app states the factors and constraints. Individual factor breakdown UI is still limited; the ranking service exposes the factor map for a future detailed explanation panel. |
| Favourites | Firestore-backed add/remove path is implemented for Firebase-authenticated users; in-memory fallback is used when Firebase is not configured. External persistence not verified here. |
| Ratings and reviews | Authenticated users can submit 1-5 star reviews with text validation through rules. Aggregate ratings are not yet computed in the client. |
| Navigation and choice history | Google Maps external directions handoff is implemented and records station context in Firestore before launch when Firebase is configured. |
| Personalization | Choice context is recorded; after at least three choices, bounded distance/speed/price adjustments are derived from recent choices and renormalized through `RankingWeights`. Firebase configuration is required; this was not externally verified here. |
| Loading/error/degraded states | Loading indicators and provider-unavailable states are present. |
| Tests | Dart ranking tests and backend recommendation tests exist. They could not be executed because Flutter/Dart telemetry writes and the local Python interpreter are blocked by the environment. |

## External setup required

1. Configure `backend/.env` from `backend/.env.example`, including `OCM_API_KEY`.
2. Add Firebase `google-services.json` under `frontend/android/app/`; enable Email/Password Authentication and deploy `firestore.rules`.
3. Replace the placeholder Maps key in `frontend/android/app/src/main/res/values/google_maps.xml` with a restricted Android key.
4. Run `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` from `frontend` on a machine with a working Flutter/Android toolchain.
