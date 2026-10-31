import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Progress through a multi-step form: "Step 2 of 4 · Background", then one bar per step that
/// fills as steps are reached, with the step names underneath. Tapping a name jumps to it
/// when [onStepTapped] is set.
class StepperProgress extends StatelessWidget {
  const StepperProgress({super.key, required this.steps, required this.current, this.onStepTapped});

  final List<String> steps;
  final int current;
  final ValueChanged<int>? onStepTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final app = AppColors.of(context);
    final duration = Motion.of(context, Motion.base);

    return Semantics(
      label: 'Step ${current + 1} of ${steps.length}: ${steps[current]}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Gaps.sm,
              children: [
                Text(
                  'Step ${current + 1} of ${steps.length}',
                  style: theme.textTheme.overline.copyWith(color: colors.primary, letterSpacing: 0.4),
                ),
                Text('·  ${steps[current]}', style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          const SizedBox(height: Gaps.sm),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: Gaps.xs + Gaps.xxs),
                Expanded(
                  child: Semantics(
                    button: onStepTapped != null,
                    selected: i == current,
                    label: '${steps[i]}${i < current ? ', done' : ''}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: onStepTapped == null ? null : () => onStepTapped!(i),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: Sizes.tapTarget - Gaps.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: duration,
                              curve: Motion.standard,
                              height: Gaps.xs,
                              decoration: BoxDecoration(
                                color: i <= current ? colors.primary : app.border,
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                            ),
                            const SizedBox(height: Gaps.xs + Gaps.xxs),
                            ExcludeSemantics(
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                style: theme.textTheme.labelSmall!.copyWith(
                                  color: i == current ? colors.onSurface : app.textMuted,
                                ),
                                child: Text(steps[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
