import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

enum AppButtonSize { regular, compact }

/// The app's one button.
///
/// * [onPressed] null → disabled.
/// * [loading] → a spinner replaces the label, the width stays, taps are ignored and
///   screen readers hear "<label>, in progress".
/// * Pressing scales it down slightly (skipped when the system asks for reduced motion).
///
///     AppButton(label: 'Log in', loading: _loading, onPressed: _submit)
///     AppButton.secondary(label: 'Save as draft', icon: Icons.save_outlined, onPressed: _save)
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;

  /// Fill the available width (forms, bottom bars) or hug the label (inline actions).
  final bool expand;
  final AppButtonSize size;

  static void _ignore() {}

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = size == AppButtonSize.compact ? Sizes.buttonHeightCompact : Sizes.buttonHeight;
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary => colors.onPrimary,
      AppButtonVariant.destructive => colors.onError,
      _ => colors.primary,
    };

    final content = AnimatedSwitcher(
      duration: Motion.of(context, Motion.fast),
      child: loading
          ? SizedBox.square(
              key: const ValueKey('loading'),
              dimension: IconSizes.md,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: spinnerColor),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: IconSizes.md), const SizedBox(width: Gaps.sm)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
              ],
            ),
    );

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : Sizes.tapTarget, height)),
      padding: size == AppButtonSize.compact
          ? const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Gaps.lg))
          : null,
    );
    // while loading the button keeps its enabled look but does nothing
    final VoidCallback? tap = onPressed == null ? null : (loading ? _ignore : onPressed);

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: tap, style: style, child: content),
      AppButtonVariant.secondary => OutlinedButton(onPressed: tap, style: style, child: content),
      AppButtonVariant.ghost => TextButton(onPressed: tap, style: style, child: content),
      AppButtonVariant.destructive => FilledButton(
        onPressed: tap,
        style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError).merge(style),
        child: content,
      ),
    };

    return Semantics(
      label: loading ? '$label, in progress' : null,
      child: PressScale(enabled: tap != null && !loading, child: button),
    );
  }
}

/// Shrinks its child slightly while a finger is down: tactile feedback for buttons and tappable cards.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || Motion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? Motion.pressScale : 1,
        duration: Motion.fast,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}
