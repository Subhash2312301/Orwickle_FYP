# Orwickle mobile: conventions

Flutter app for Project Owners, Investors and Buyers. State: `provider` + `StatefulWidget`; routing:
`go_router`; HTTP: `dio`. Backend contracts, models and auth logic live in `features/*/data`,
`features/auth/session` and `core/network`; UI work must not change them.

## Folder structure

```
lib/core/theme      tokens.dart, colors.dart, typography.dart, app_theme.dart, theme_controller.dart
lib/core/widgets    design-system components; import 'core/widgets/widgets.dart'
lib/core/motion     transitions.dart (page transitions, FadeThroughBranches), entrance.dart
lib/core/router     routes.dart (paths, role rules), app_router.dart (redirects, shell branches)
lib/features/<name> data/ (API + models), screens/, widgets/
```

## Design rules

- Import `core/theme/app_theme.dart` (it exports tokens, colours and typography) and
  `core/widgets/widgets.dart`.
- No raw values in screens: spacing `Gaps.*`, radii `Radii.*`, icon sizes `IconSizes.*`, fixed sizes
  `Sizes.*`, durations and curves `Motion.*`, shadows `Elevations.*`.
- Colours come from `Theme.of(context).colorScheme` or `AppColors.of(context)`. Meaning colours are
  `Tone(fg, bg)`; widgets that take a colour take a `ToneRole` so they can stay `const`.
  Listing types: `funding` (amber), `sale` (teal). Statuses: use `AppStatus` + `StatusChip.status`.
  `Palette` is only for the theme files and the always-dark brand surfaces.
- Text styles from `textTheme`; money and counts use `textTheme.numeric()` (Inter, keep weight ≤ w700:
  only 400–700 are bundled).
- Buttons: `AppButton` (primary), `.secondary`, `.ghost`, `.destructive`; `loading:` for async work.
- Inputs: `AppTextField` / `AppDropdownField`; server errors via `serverError:`; custom form fields show
  errors with `FieldError`.
- Every async screen has loading (`Skeleton`), empty (`EmptyState`), error and offline (`ErrorState.from`)
  states. `AsyncView` does all four with a crossfade. Error / empty states inside a `RefreshIndicator`
  must sit in a scrollable.
- Dialogs `confirmAction` / `AppDialog`, sheets `showAppBottomSheet` + `SheetOption`, messages `showAppToast`.
- The platform disclaimer is always `DisclaimerBanner` (one wording, in one place).
- Accessibility: 48 dp tap targets (`Sizes.tapTarget`), semantic labels on icon-only buttons (tooltip) and
  images, colour never the only cue (chips have icon + word), layouts must survive 1.3–1.5× text and 360 dp.
- Motion: use `Motion.of(context, …)` for durations and `.entrance(context, index: i)` for list items; both
  respect reduced motion. Do not use `flutter_animate`'s `delay:` in widgets that tests pump briefly
  (it leaves a pending timer).

## Adding a screen

1. Create `features/<name>/screens/<name>_screen.dart`; build it from the components above
   (`AppAppBar`, `SectionHeader`, `AppCard`, …) inside a `ConstrainedBox(maxWidth: Sizes.maxContentWidth)`.
2. Add the path to `Routes` (and to `Routes.allowedFor` if only some roles may open it).
3. Register it in `app_router.dart`: a normal `GoRoute` for pushed pages (shared-axis transition from the
   theme), `slideUpPage` for create flows, `fadeThroughPage` for top-level switches.
   A new bottom tab = a new `StatefulShellBranch` + an entry in `Branches` and `tabsFor` in
   `features/shell/app_shell.dart`.
4. Not wired to the backend yet? Use mock data and mark it `// TODO: wire in Week X`.

## Checks before committing

```
dart format lib test      # page width 120 (analysis_options.yaml)
flutter analyze           # must be clean
flutter test              # widget tests + goldens; update goldens only for intended UI changes
```
