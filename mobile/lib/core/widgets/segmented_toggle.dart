import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chips.dart';

/// One option of a [SegmentedToggle].
class ToggleSegment<T> {
  const ToggleSegment({required this.value, required this.label, this.icon, this.role = ToneRole.info});

  final T value;
  final String label;
  final IconData? icon;

  /// Colour of the label and indicator outline when selected (funding amber, sale teal...).
  final ToneRole role;
}

/// Pill-shaped switch between two to four options with a sliding indicator, e.g. Funding | Sales.
/// Each segment is at least 48 dp tall and is announced as a selected / unselected button.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({super.key, required this.segments, required this.value, required this.onChanged});

  final List<ToggleSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final index = segments.indexWhere((s) => s.value == value).clamp(0, segments.length - 1);
    final selectedTone = segments[index].role.resolve(context);
    final duration = Motion.of(context, Motion.base);
    // -1 … 1 across the track
    final x = segments.length == 1 ? 0.0 : -1 + 2 * index / (segments.length - 1);

    return Container(
      height: Sizes.tapTarget + Gaps.sm,
      padding: const EdgeInsets.all(Gaps.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(x, 0),
            duration: duration,
            curve: Motion.emphasized,
            child: FractionallySizedBox(
              widthFactor: 1 / segments.length,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: duration,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: selectedTone.fg.withValues(alpha: 0.35)),
                  boxShadow: Elevations.sm(app.shadow),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final segment in segments)
                Expanded(
                  child: _SegmentButton(segment: segment, selected: segment.value == value, onTap: onChanged),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({required this.segment, required this.selected, required this.onTap});

  final ToggleSegment<T> segment;
  final bool selected;
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? segment.role.resolve(context).fg : AppColors.of(context).textMuted;
    final style = theme.textTheme.labelLarge!.copyWith(color: color);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: onTap == null ? null : () => onTap!(segment.value),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: Motion.of(context, Motion.fast),
            style: style,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.icon != null) ...[
                  Icon(segment.icon, size: IconSizes.sm, color: color),
                  const SizedBox(width: Gaps.xs + Gaps.xxs),
                ],
                Flexible(child: Text(segment.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
