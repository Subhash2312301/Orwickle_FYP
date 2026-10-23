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

Logged out, the app opens on the Welcome screen (choose a role → register → email code → home).
In development the OTP email is printed in the backend terminal. `/system-check` still shows the app → backend → database health check.

On a real phone (same Wi-Fi as the laptop):

```
flutter run --dart-define=API_BASE_URL=http://<laptop IP from ipconfig>:4000/api
```

## Structure

```
lib/
  main.dart, app.dart          wiring: ApiClient → AuthApi → SessionController, providers, router
  core/
    config/app_config.dart     API base URL and timeouts
    network/api_client.dart    Dio client; auth requests carry the access token, retry once after refresh
    router/                    routes + redirects that follow the login state
    storage/token_storage.dart refresh token in Android Keystore / iOS Keychain
    theme/app_theme.dart       Material 3 theme
    validation/validators.dart form rules, same as the backend's
  features/
    auth/
      data/                    AuthApi, models (AppUser, AuthSession, UserRole)
      session/                 SessionController: login state, 15-minute inactivity logout, token refresh
      screens/                 splash, welcome, register, verify email, login, forgot / reset password
      widgets/                 OTP boxes, password field + checklist, resend countdown
    home/                      placeholder home
    system_check/              health screen
```

### Session rules
- Any touch restarts a 15-minute countdown; when it runs out (or the app returns from the background after 15 minutes) the user is logged out and the login screen explains why.
- While the user is active the session is renewed on the server every 2 minutes, so the backend's own 15-minute check agrees with the app.
- Refreshes never run in parallel: the backend treats a reused refresh token as stolen and ends every session.

New features go in `features/<name>/` with their screens and services.

## Checks

```
flutter analyze
flutter test
```

## Notes

- Debug builds allow plain `http://` to reach the local backend; release builds require HTTPS.
- The Android build needs NDK 28.2.13676358 (Flutter's default). Install it from Android Studio → SDK Manager → SDK Tools → NDK (Side by side) if the build tries to download it.
