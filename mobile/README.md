# Orwickle Mobile App

Flutter app (Android and iOS) for Project Owners, Investors and Buyers. Flutter 3.47, Dart 3.13.

## Run

1. Start the backend first: `cd backend && npm run dev`.
2. Start an emulator: `flutter emulators --launch Pixel_5`.
3. Run the app:

```
cd mobile
flutter pub get
flutter run
```

The first screen is a system check that calls `GET /api/health`. All three rows green means app → backend → database works.

On a real phone (same Wi-Fi as the laptop):

```
flutter run --dart-define=API_BASE_URL=http://<laptop IP from ipconfig>:4000/api
```

## Structure

```
lib/
  main.dart, app.dart        entry point, MaterialApp + theme + router
  core/
    config/app_config.dart   API base URL and timeouts
    network/api_client.dart  Dio client, turns every failure into ApiException
    router/app_router.dart   go_router routes
    theme/app_theme.dart     Material 3 theme
  features/
    system_check/            Phase 1 health screen
```

New features go in `features/<name>/` with their screens and services.

## Checks

```
flutter analyze
flutter test
```

## Notes

- Debug builds allow plain `http://` to reach the local backend; release builds require HTTPS.
- The Android build needs NDK 28.2.13676358 (Flutter's default). Install it from Android Studio → SDK Manager → SDK Tools → NDK (Side by side) if the build tries to download it.
