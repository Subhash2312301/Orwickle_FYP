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
  main.dart, app.dart          wiring: ApiClient → AuthApi → SessionController, theme, providers, router
  core/
    config/app_config.dart     API base URL, timeouts, DEV_TOOLS flag, version
    network/api_client.dart    Dio client; auth requests carry the access token, retry once after refresh
    router/                    routes, role guards, one StatefulShellRoute branch per tab
    motion/                    page transitions (shared axis, fade through, slide up), staggered entrance
    storage/                   refresh token and onboarding flag (secure storage)
    theme/                     design tokens, colours, type scale, light / dark themes, ThemeController
    validation/validators.dart form rules, same as the backend's
    widgets/                   design-system components (import widgets.dart)
  features/
    auth/
      data/                    AuthApi, models (AppUser, AuthSession, UserRole)
      session/                 SessionController: login state, 15-minute inactivity logout, token refresh
      screens/                 splash, onboarding, welcome, register, verify email, login, password screens
      widgets/                 auth layout, OTP boxes, password field + checklist, resend countdown
    profile/                   4-step profile setup / edit, document uploads
    home/                      owner home, profile tab
    listings/                  my listings, create / edit wizard, listing detail, ListingCard
    discover/                  Discover and Saved (UI scaffolds on mock data, wired in Week 9)
    requests/                  access requests and offers (UI scaffolds, wired in Weeks 10–11)
    settings/                  appearance, account, about
    shell/                     AppShell (bottom navigation per role), approval banner, "coming soon"
    design_system/             component gallery (developer builds only: /#/design-system)
    system_check/              health screen (developer builds only)
```

### Session rules
- Any touch restarts a 15-minute countdown; when it runs out (or the app returns from the background after 15 minutes) the user is logged out and the login screen explains why.
- While the user is active the session is renewed on the server every 2 minutes, so the backend's own 15-minute check agrees with the app.
- Refreshes never run in parallel: the backend treats a reused refresh token as stolen and ends every session.

New features go in `features/<name>/` with their screens and services.

## Design system

The look is **calm confidence**: a deep ink base, one cobalt accent for trust, **amber for projects
seeking funding** and **teal for projects for sale**, so the two listing types are told apart at a glance.
Everything lives in `lib/core/theme` and `lib/core/widgets`; screens never hard-code colours, text styles,
spacing or radii.

| Part | Where | What |
|---|---|---|
| Colours | `theme/colors.dart` | `Palette` (raw values) and the `AppColors` theme extension: `funding`, `sale`, `pending`, `approved`, `rejected`, `expired`, `countered`, `verified`, each a `Tone(fg, bg)` that meets WCAG AA (checked by a test) |
| Type | `theme/typography.dart` | Sora for headings, Inter for text, `textTheme.numeric()` for money (tabular figures), `textTheme.overline` labels. Fonts are bundled in `assets/google_fonts` (Inter 400–700, Sora 400–800) |
| Tokens | `theme/tokens.dart` | `Gaps` (4-point spacing), `Radii`, `IconSizes`, `Sizes` (48 dp tap target), `Elevations`, `Motion` (150 / 250 / 400 ms, easeOutCubic and emphasized curves) |
| Themes | `theme/app_theme.dart` | Material 3 light and dark; Settings → Appearance switches System / Light / Dark |
| Components | `widgets/` | AppButton, AppTextField, AppDropdownField, AppCard, StatusChip, ListingTypeChip, CategoryChip, RoleBadge, VerifiedBadge, SectionHeader, EmptyState, ErrorState, Skeleton, AppBanner, DisclaimerBanner, bottom sheet / dialog / toast, AppAppBar, SegmentedToggle, StepperProgress, AppAvatar, Timeline, AnimatedCounter, SuccessCheck, AsyncView |
| Motion | `motion/` | shared-axis pushes, fade-through tab and top-level changes, slide-up for creating, Hero from card to detail, staggered entrances; all skipped when the phone asks for reduced motion |

Every component, in light and dark, is on **/#/design-system** in a developer build.

## Checks

```
flutter analyze
flutter test                                   # everything, including goldens
flutter test --tags golden                     # screenshot tests only
flutter test --tags golden --update-goldens    # after an intended UI change
```

Golden images (light and dark) are in `test/goldens/files`. They were rendered on Windows; another OS can
differ by a few pixels of text anti-aliasing.

## Web build on localhost

```
flutter build web --dart-define=API_BASE_URL=http://localhost:4000/api --dart-define=DEV_TOOLS=true
```

Then serve `build/web` with any static server, for example on port 5050.

## Notes

- Debug builds allow plain `http://` to reach the local backend; release builds require HTTPS.
- The Android build needs NDK 28.2.13676358 (Flutter's default). Install it from Android Studio → SDK Manager → SDK Tools → NDK (Side by side) if the build tries to download it.
