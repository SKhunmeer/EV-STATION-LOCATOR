# Chargewise Flutter client

This Android Flutter client uses Provider state management, Firebase Authentication/Firestore when `google-services.json` is installed, Google Maps, device location, and the Flask/Open Charge Map station adapter.

Run from this directory:

```bash
flutter pub get
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
flutter build apk --debug
```

Before running, replace the placeholder in `android/app/src/main/res/values/google_maps.xml`, add Firebase `google-services.json`, and configure the backend `OCM_API_KEY`. No station is fabricated when the provider is not configured.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
