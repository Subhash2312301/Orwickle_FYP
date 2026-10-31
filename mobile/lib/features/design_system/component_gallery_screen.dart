import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/widgets.dart';

/// Developer page showing every design-system component and its states, in light or dark.
/// Debug builds only (/design-system); handy for checking changes and for report screenshots.
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  final _text = TextEditingController();
  final _password = TextEditingController();
  bool _funding = true;
  int _step = 1;
  bool _loading = false;
  final _selected = <String>{'FinTech'};

  static const _categories = ['FinTech', 'EdTech', 'HealthTech', 'E-commerce', 'AI / ML'];

  static const _offers = [
    TimelineEntry(
      title: 'Offer from Ali (Investor)',
      time: '2 Nov, 10:15',
      amount: 'PKR 1,000,000',
      detail: '10% equity · expires 9 Nov',
      icon: Icons.local_offer_outlined,
      status: AppStatus.countered,
      role: ToneRole.countered,
    ),
    TimelineEntry(
      title: 'Counteroffer from you',
      time: '3 Nov, 18:40',
      amount: 'PKR 1,400,000',
      detail: '8% equity · expires 10 Nov',
      icon: Icons.swap_horiz,
      subtitle: 'Happy to go lower on equity if the amount moves up.',
      status: AppStatus.pending,
      role: ToneRole.pending,
      isCurrent: true,
    ),
  ];

  @override
  void dispose() {
    _text.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themes = context.watch<ThemeController>();
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppAppBar(
        title: 'Design system',
        subtitle: 'Orwickle components',
        actions: [
          IconButton(
            tooltip: dark ? 'Light theme' : 'Dark theme',
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => themes.setMode(dark ? ThemeMode.light : ThemeMode.dark),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxxl),
        children: [
          const SectionHeader('Typography', overline: 'Sora + Inter'),
          Text('Display', style: theme.textTheme.displaySmall),
          Text('Headline', style: theme.textTheme.headlineMedium),
          Text('Title large', style: theme.textTheme.titleLarge),
          Text('Body text reads comfortably at every size.', style: theme.textTheme.bodyLarge),
          Text('Small muted body text', style: theme.textTheme.bodySmall),
          Text('PKR 1,250,000', style: theme.textTheme.numeric(size: 24)),

          const SectionHeader('Buttons'),
          AppButton(
            label: 'Primary',
            icon: Icons.arrow_forward,
            loading: _loading,
            onPressed: () async {
              setState(() => _loading = true);
              await Future<void>.delayed(const Duration(seconds: 2));
              if (mounted) setState(() => _loading = false);
            },
          ),
          const SizedBox(height: Gaps.md),
          AppButton.secondary(label: 'Secondary', onPressed: () {}),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              Expanded(
                child: AppButton.destructive(label: 'Destructive', onPressed: () {}),
              ),
              const SizedBox(width: Gaps.md),
              const Expanded(child: AppButton(label: 'Disabled', onPressed: null)),
            ],
          ),
          AppButton.ghost(label: 'Ghost', onPressed: () {}),

          const SectionHeader('Inputs'),
          AppTextField(controller: _text, label: 'Project title', icon: Icons.title, hint: 'e.g. Smart irrigation kit'),
          const SizedBox(height: Gaps.lg),
          AppTextField(controller: _password, label: 'Password', icon: Icons.lock_outline, password: true),
          const SizedBox(height: Gaps.lg),
          AppTextField(
            controller: TextEditingController(text: 'abc'),
            label: 'With error',
            icon: Icons.mail_outline,
            serverError: 'Enter a valid email address',
          ),

          const SectionHeader('Toggle'),
          SegmentedToggle<bool>(
            value: _funding,
            onChanged: (v) => setState(() => _funding = v),
            segments: const [
              ToggleSegment(value: true, label: 'Funding', icon: Icons.trending_up, role: ToneRole.funding),
              ToggleSegment(value: false, label: 'Sales', icon: Icons.sell_outlined, role: ToneRole.sale),
            ],
          ),

          const SectionHeader('Chips & badges'),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              const ListingTypeChip(isFunding: true),
              const ListingTypeChip(isFunding: false),
              for (final s in AppStatus.values) StatusChip.status(s),
              const RoleBadge(role: 'owner', label: 'Project Owner'),
              const RoleBadge(role: 'investor', label: 'Investor'),
              const RoleBadge(role: 'buyer', label: 'Buyer'),
              const VerifiedBadge(showLabel: true),
            ],
          ),
          const SizedBox(height: Gaps.md),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              for (final c in _categories)
                CategoryChip(
                  label: c,
                  selected: _selected.contains(c),
                  onSelected: (on) => setState(() => on ? _selected.add(c) : _selected.remove(c)),
                ),
            ],
          ),

          const SectionHeader('Avatar & counters'),
          Row(
            children: [
              const AppAvatar(initials: 'SR', size: 56, verified: true),
              const SizedBox(width: Gaps.lg),
              const AppAvatar(initials: 'AK', size: 40),
              const Spacer(),
              AnimatedCounter(value: _funding ? 12 : 7),
            ],
          ),

          const SectionHeader('Stepper'),
          StepperProgress(
            steps: const ['Type', 'Preview', 'Confidential', 'Review'],
            current: _step,
            onStepTapped: (i) => setState(() => _step = i),
          ),

          const SectionHeader('Cards & banners'),
          AppCard(
            onTap: () {},
            child: Text('Outlined card, tappable', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: Gaps.md),
          AppCard(
            variant: AppCardVariant.tinted,
            child: Text('Tinted card for callouts', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: Gaps.lg),
          const AppBanner(
            title: 'Account under review',
            message: 'An admin is checking your profile.',
            role: ToneRole.pending,
            icon: Icons.hourglass_top,
          ),
          const AppBanner(
            message: 'Could not save. Check the highlighted fields.',
            role: ToneRole.rejected,
            icon: Icons.error_outline,
          ),
          const DisclaimerBanner(),

          const SectionHeader('Offer timeline'),
          const Timeline(entries: _offers),

          const SectionHeader('Skeleton'),
          const Skeleton(
            child: Row(
              children: [
                SkeletonBox.circle(size: 48),
                SizedBox(width: Gaps.md),
                Expanded(child: SkeletonLines()),
              ],
            ),
          ),

          const SectionHeader('Feedback'),
          const Center(child: SuccessCheck()),
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No listings yet',
            message: 'Your projects will appear here.',
          ),
          ErrorState(message: 'Cannot reach the server.', offline: true, onRetry: () {}),

          const SectionHeader('Overlays'),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              AppButton.secondary(
                label: 'Sheet',
                expand: false,
                onPressed: () => showAppBottomSheet<void>(
                  context,
                  title: 'Filters',
                  builder: (context) => const Column(
                    children: [
                      SheetOption(icon: Icons.photo_library_outlined, label: 'Choose from gallery'),
                      SheetOption(icon: Icons.delete_outline, label: 'Remove', destructive: true),
                    ],
                  ),
                ),
              ),
              AppButton.secondary(
                label: 'Dialog',
                expand: false,
                onPressed: () => confirmAction(
                  context,
                  icon: Icons.delete_outline,
                  title: 'Delete draft?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                ),
              ),
              AppButton.secondary(
                label: 'Toast',
                expand: false,
                onPressed: () => showAppToast(context, 'Listing saved', role: ToneRole.approved),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
