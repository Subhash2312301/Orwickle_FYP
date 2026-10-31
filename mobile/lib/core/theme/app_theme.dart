import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

export 'colors.dart';
export 'tokens.dart';
export 'typography.dart';

/// Orwickle's look: "calm confidence". A deep ink base, one cobalt accent for trust,
/// amber for projects seeking funding and teal for projects for sale.
/// Every screen takes colours, text styles and shapes from here (import this one file).
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(_lightScheme, AppColors.light);
  static ThemeData get dark => _build(_darkScheme, AppColors.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Palette.cobalt600,
    onPrimary: Palette.white,
    primaryContainer: Palette.cobalt100,
    onPrimaryContainer: Palette.cobalt700,
    secondary: Palette.ink700,
    onSecondary: Palette.white,
    secondaryContainer: Palette.slate100,
    onSecondaryContainer: Palette.ink900,
    tertiary: Palette.teal700,
    onTertiary: Palette.white,
    tertiaryContainer: Palette.teal50,
    onTertiaryContainer: Palette.teal700,
    error: Palette.red700,
    onError: Palette.white,
    errorContainer: Palette.red50,
    onErrorContainer: Palette.red700,
    surface: Palette.white,
    onSurface: Palette.ink900,
    onSurfaceVariant: Palette.slate600,
    surfaceContainerLowest: Palette.white,
    surfaceContainerLow: Palette.paper,
    surfaceContainer: Palette.slate100,
    surfaceContainerHigh: Palette.slate100,
    surfaceContainerHighest: Palette.slate200,
    outline: Palette.slate400,
    outlineVariant: Palette.slate200,
    shadow: Palette.ink900,
    scrim: Palette.ink950,
    inverseSurface: Palette.ink900,
    onInverseSurface: Palette.white,
    inversePrimary: Palette.cobalt400,
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.cobalt400,
    onPrimary: Palette.ink950,
    primaryContainer: Palette.cobalt900,
    onPrimaryContainer: Palette.cobalt200,
    secondary: Palette.slate300,
    onSecondary: Palette.ink900,
    secondaryContainer: Palette.ink700,
    onSecondaryContainer: Palette.white,
    tertiary: Palette.teal300,
    onTertiary: Palette.ink950,
    tertiaryContainer: Palette.teal950,
    onTertiaryContainer: Palette.teal300,
    error: Palette.red300,
    onError: Palette.ink950,
    errorContainer: Palette.red950,
    onErrorContainer: Palette.red300,
    surface: Palette.ink900,
    onSurface: Palette.slate100,
    onSurfaceVariant: Palette.slate300,
    surfaceContainerLowest: Palette.ink950,
    surfaceContainerLow: Palette.ink900,
    surfaceContainer: Palette.ink800,
    surfaceContainerHigh: Palette.ink700,
    surfaceContainerHighest: Palette.ink600,
    outline: Palette.slate500,
    outlineVariant: Palette.ink600,
    shadow: Palette.ink950,
    scrim: Palette.ink950,
    inverseSurface: Palette.slate100,
    onInverseSurface: Palette.ink900,
    inversePrimary: Palette.cobalt600,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme colors, AppColors app) {
    final text = AppTypography.textTheme(colors.onSurface, app.textMuted);
    RoundedRectangleBorder rounded(double radius, {BorderSide side = BorderSide.none}) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
    OutlineInputBorder inputBorder(Color color, [double width = Sizes.hairline]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: color, width: width),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: Gaps.xl);
    // filled buttons fill their row by default (forms, bottom bars); AppButton(expand: false) hugs
    const buttonSize = Size.fromHeight(Sizes.buttonHeight);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      extensions: [app],
      textTheme: text,
      scaffoldBackgroundColor: app.canvas,
      canvasColor: app.canvas,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(color: app.border, thickness: Sizes.hairline, space: Gaps.xl),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: IconSizes.lg),
      appBarTheme: AppBarTheme(
        backgroundColor: app.canvas,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: Gaps.page,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: rounded(Radii.lg, side: BorderSide(color: app.border)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
        minVerticalPadding: Gaps.md,
        iconColor: colors.onSurfaceVariant,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: rounded(Radii.md),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.lg),
        labelStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        floatingLabelStyle: text.labelLarge?.copyWith(color: colors.primary),
        hintStyle: text.bodyMedium?.copyWith(color: app.textMuted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: colors.error),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? colors.primary : colors.onSurfaceVariant,
        ),
        border: inputBorder(app.border),
        enabledBorder: inputBorder(app.border),
        focusedBorder: inputBorder(colors.primary, Sizes.focusRing),
        errorBorder: inputBorder(colors.error),
        focusedErrorBorder: inputBorder(colors.error, Sizes.focusRing),
        disabledBorder: inputBorder(app.border.withValues(alpha: 0.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: rounded(Radii.md),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          disabledBackgroundColor: colors.onSurface.withValues(alpha: 0.1),
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(Sizes.tapTarget, Sizes.buttonHeight),
          padding: buttonPadding,
          foregroundColor: colors.onSurface,
          side: BorderSide(color: app.borderStrong),
          shape: rounded(Radii.md),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(Sizes.tapTarget, Sizes.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
          shape: rounded(Radii.md),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(Sizes.tapTarget, Sizes.tapTarget)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: rounded(Radii.lg),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
      chipTheme: ChipThemeData(
        shape: rounded(Radii.pill),
        side: BorderSide(color: app.border),
        backgroundColor: colors.surface,
        selectedColor: colors.primaryContainer,
        checkmarkColor: colors.onPrimaryContainer,
        labelStyle: text.labelLarge?.copyWith(color: colors.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: colors.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: Gaps.sm, vertical: Gaps.xs),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(Sizes.tapTarget, Sizes.tapTarget),
          side: BorderSide(color: app.border),
          selectedBackgroundColor: colors.primaryContainer,
          selectedForegroundColor: colors.onPrimaryContainer,
          textStyle: text.labelLarge,
          shape: rounded(Radii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: Sizes.navBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        indicatorShape: rounded(Radii.pill),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? colors.onSurface : colors.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: IconSizes.lg,
            color: states.contains(WidgetState.selected) ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: app.borderStrong,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded(Radii.xl),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: colors.onInverseSurface),
        actionTextColor: colors.inversePrimary,
        shape: rounded(Radii.md),
        insetPadding: const EdgeInsets.all(Gaps.lg),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.primaryContainer,
        circularTrackColor: Colors.transparent,
      ),
      checkboxTheme: CheckboxThemeData(shape: rounded(Radii.xs)),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: colors.inverseSurface, borderRadius: BorderRadius.circular(Radii.sm)),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
      ),
    );
  }
}
