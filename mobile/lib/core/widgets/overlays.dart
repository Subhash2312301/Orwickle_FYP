import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'chips.dart';

/// Bottom sheet with a drag handle, an optional title and scrollable content that sizes to fit.
/// Slides up; safe-area aware; content scrolls on short screens.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, Gaps.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
                    if (subtitle != null) ...[
                      const SizedBox(height: Gaps.xs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.of(context).textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, Gaps.xl),
                child: builder(context),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// One row of an option sheet (e.g. gallery / camera / remove).
class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.sm),
      leading: Container(
        width: Sizes.tapTarget - Gaps.sm,
        height: Sizes.tapTarget - Gaps.sm,
        decoration: BoxDecoration(
          color: destructive ? colors.errorContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(icon, size: IconSizes.md, color: color),
      ),
      title: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}

/// Asks the user to confirm an action. Returns true only when they confirm.
/// [destructive] paints the confirm button red (delete, close, log out).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: icon,
        title: title,
        message: message,
        destructive: destructive,
        actions: [
          AppButton.ghost(label: cancelLabel, onPressed: () => Navigator.pop(context, false)),
          destructive
              ? AppButton.destructive(
                  label: confirmLabel,
                  expand: false,
                  size: AppButtonSize.compact,
                  onPressed: () => Navigator.pop(context, true),
                )
              : AppButton(
                  label: confirmLabel,
                  expand: false,
                  size: AppButtonSize.compact,
                  onPressed: () => Navigator.pop(context, true),
                ),
        ],
      ),
    ) ??
    false;

/// Dialog layout: an icon in a tinted circle, a title, a message or [content], and actions.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.icon,
    this.actions = const [],
    this.destructive = false,
  });

  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final List<Widget> actions;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tone = (destructive ? ToneRole.rejected : ToneRole.info).resolve(context);
    return AlertDialog(
      icon: icon == null
          ? null
          : Container(
              padding: const EdgeInsets.all(Gaps.md),
              decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
              child: Icon(icon, color: tone.fg, size: IconSizes.lg),
            ),
      title: Text(title, textAlign: icon == null ? TextAlign.start : TextAlign.center),
      content: content ?? (message == null ? null : Text(message!)),
      actionsPadding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.lg),
      actions: actions,
    );
  }
}

/// Short message at the bottom of the screen. [role] adds a coloured icon (success, error...).
void showAppToast(BuildContext context, String message, {ToneRole role = ToneRole.neutral, IconData? icon}) {
  final colors = Theme.of(context).colorScheme;
  final symbol =
      icon ??
      switch (role) {
        ToneRole.approved => Icons.check_circle_rounded,
        ToneRole.rejected => Icons.error_rounded,
        ToneRole.pending => Icons.info_rounded,
        _ => null,
      };
  // the toast sits on the inverse surface, so use the opposite theme's colour for the icon
  final dark = Theme.of(context).brightness == Brightness.dark;
  final inverse = dark ? AppColors.light : AppColors.dark;
  final iconColor = switch (role) {
    ToneRole.approved => inverse.approved.fg,
    ToneRole.rejected => inverse.rejected.fg,
    ToneRole.pending => inverse.pending.fg,
    _ => colors.onInverseSurface,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (symbol != null) ...[Icon(symbol, color: iconColor, size: IconSizes.md), const SizedBox(width: Gaps.md)],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Toast for a failed request.
void showErrorToast(BuildContext context, ApiException error) =>
    showAppToast(context, error.message, role: ToneRole.rejected, icon: error.isNetworkError ? Icons.wifi_off : null);
