import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/session/session_controller.dart';
import '../../auth/widgets/form_widgets.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/widgets/profile_fields.dart';
import '../data/listing_api.dart';
import '../data/listing_models.dart';
import '../widgets/listing_widgets.dart';

/// Create a listing (no [listingId]) or edit one, as a four-step wizard:
/// type & price → public preview → confidential details → review.
/// Rules match backend/src/modules/listings/listing.validation.js.
/// The public preview and the confidential details are separate steps, as they are stored separately.
/// A draft can be saved from any step, or saved and published (sent for admin review) from the review.
/// Every step stays built, so saving checks all of them and opens the first one with a problem.
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, this.listingId});

  final String? listingId;

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  static const _stepTitles = ['Type & price', 'Public preview', 'Confidential', 'Review'];

  final _forms = List.generate(3, (_) => GlobalKey<FormState>()); // the review step has no fields
  final _scroll = ScrollController();
  final _c = <String, TextEditingController>{};
  int _step = 0;

  late Future<void> _loading;
  List<Category> _categories = const [];
  String _type = 'funding';
  bool _typeLocked = false; // only drafts may change type
  bool _isDraft = true;
  final List<UploadFile> _newPhotos = []; // picked on a new listing, uploaded after it is created
  String? _categoryId;
  String? _stage;
  List<String> _techStack = [];
  bool _saving = false;
  Map<String, String> _serverErrors = const {};

  bool get _editing => widget.listingId != null;
  bool get _funding => _type == 'funding';
  bool get _onReview => _step == _stepTitles.length - 1;

  TextEditingController _ctl(String key) => _c.putIfAbsent(key, TextEditingController.new);
  String _t(String key) => _ctl(key).text.trim();

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<void> _load() async {
    _categories = await context.read<ProfileApi>().categories();
    if (!_editing || !mounted) return;
    final detail = await context.read<ListingApi>().get(widget.listingId!);
    final l = detail.listing;
    _type = l.listingType;
    _typeLocked = l.status != 'draft';
    _isDraft = l.status == 'draft';
    _categoryId = l.categoryId;
    _stage = l.projectStage;
    _techStack = [...l.techStack];
    _ctl('title').text = l.title;
    _ctl('shortDescription').text = l.shortDescription;
    _ctl('askingAmount').text = l.askingAmount?.round().toString() ?? '';
    final c = detail.confidential;
    for (final key in confidentialLabels.keys) {
      _ctl(key).text = c?.text(key) ?? '';
    }
    final equity = c?.equityOfferedPercent;
    _ctl('equityOfferedPercent').text = equity == null ? '' : (equity % 1 == 0 ? '${equity.toInt()}' : '$equity');
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic> _body() => {
    'listingType': _type,
    'categoryId': _categoryId,
    'title': _t('title'),
    'shortDescription': _t('shortDescription'),
    'techStack': _techStack,
    'projectStage': _stage,
    'askingAmount': num.tryParse(_t('askingAmount')),
    'confidential': {
      for (final key in confidentialLabels.keys)
        if (key != 'transferDetails' || !_funding) key: _t(key),
      'equityOfferedPercent': _funding ? num.tryParse(_t('equityOfferedPercent')) : null,
    },
  };

  void _goTo(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    if (_onReview) return;
    if (_forms[_step].currentState?.validate() ?? true) _goTo(_step + 1);
  }

  /// Checks every step and returns the first one with a problem; null when all are fine.
  int? _firstInvalidStep() {
    int? first;
    for (var i = 0; i < _forms.length; i++) {
      final valid = _forms[i].currentState?.validate() ?? true; // validate all so every error shows
      if (!valid) first ??= i;
    }
    return first;
  }

  Future<void> _pickPhoto() async {
    final choice = await pickImage(context, canRemove: false);
    if (choice is PickedImage && mounted) setState(() => _newPhotos.add(choice.file));
  }

  // Photos are uploaded before publishing, so adding them does not send a just-published listing back to review.
  Future<void> _save({bool publish = false}) async {
    setState(() => _serverErrors = const {});
    final invalid = _firstInvalidStep();
    if (invalid != null) {
      _goTo(invalid);
      showInfoSnack(context, 'Please correct the highlighted fields');
      return;
    }
    setState(() => _saving = true);
    final api = context.read<ListingApi>();
    String? id = widget.listingId;
    try {
      id = (_editing ? await api.update(id!, _body()) : await api.create(_body())).listing.id;
      for (final photo in _newPhotos) {
        await api.addPhoto(id, photo);
      }
      if (publish) await api.changeStatus(id, 'publish');
      if (!mounted) return;
      if (_editing) {
        showAppToast(context, publish ? 'Listing published' : 'Listing saved', role: ToneRole.approved);
        context.pop(true);
      } else {
        await _celebrate(published: publish);
        if (mounted) context.pushReplacement(Routes.listing(id));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // the listing was created but a photo or publishing failed: show it, so nothing is created twice
      if (!_editing && id != null) {
        showErrorSnack(context, e);
        context.pushReplacement(Routes.listing(id));
        return;
      }
      if (e.fieldErrors.isNotEmpty) {
        // "confidential.fullDescription" → "fullDescription"
        setState(
          () => _serverErrors = {
            for (final entry in e.fieldErrors.entries) entry.key.replaceFirst('confidential.', ''): entry.value,
          },
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final step = mounted ? _firstInvalidStep() : null;
          if (step != null) _goTo(step);
        });
        showInfoSnack(context, e.message);
      } else {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The success moment after creating a listing: an animated tick and what happens next.
  Future<void> _celebrate({required bool published}) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AppDialog(
      title: published ? 'Listing published' : 'Draft saved',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SuccessCheck(size: 88),
          const SizedBox(height: Gaps.lg),
          Text(
            published
                ? 'An admin will review it. Investors and buyers see it once it is approved.'
                : 'Only you can see it. Publish it from the listing page when you are ready.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [AppButton(label: 'View listing', onPressed: () => Navigator.pop(context))],
    ),
  );

  // ---------- form pieces ----------

  Widget _text(
    String key,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Gaps.lg),
    child: AppTextField(
      controller: _ctl(key),
      label: label,
      hint: hint,
      icon: icon,
      validator: validator,
      serverError: _serverErrors[key],
      maxLines: maxLines,
      maxLength: maxLength,
      showCounter: maxLength != null && maxLines > 1,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: TextCapitalization.sentences,
    ),
  );

  Widget _dropdown<T>(
    String label,
    T? value,
    Map<T, String> options,
    ValueChanged<T?> onChanged,
    String errorKey,
    IconData icon, {
    required String requiredError,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Gaps.lg),
    child: AppDropdownField<T>(
      label: label,
      value: value,
      options: options,
      onChanged: (v) => setState(() => onChanged(v)),
      requiredError: requiredError,
      serverError: _serverErrors[errorKey],
      icon: icon,
    ),
  );

  String? _equity(String? v) {
    final n = num.tryParse(v?.trim() ?? '');
    if ((v ?? '').trim().isEmpty) return 'Equity offered is required for funding listings';
    if (n == null) return 'Equity must be a number';
    if (n <= 0) return 'Equity must be more than 0%';
    if (n > 100) return 'Equity cannot be more than 100%';
    return null;
  }

  // ---------- steps ----------

  List<Widget> _typeStep() {
    final theme = Theme.of(context);
    return [
      const SectionTitle('What kind of listing is this?', subtitle: 'Investors see funding, buyers see sales.'),
      for (final (isFunding, title, body) in const [
        (true, 'Seeking Funding', 'Raise money from investors in exchange for equity.'),
        (false, 'Available for Purchase', 'Sell the project (code, design, rights) to a buyer.'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: Gaps.md),
          child: _TypeCard(
            isFunding: isFunding,
            title: title,
            body: body,
            selected: _funding == isFunding,
            onTap: _typeLocked ? null : () => setState(() => _type = isFunding ? 'funding' : 'sale'),
          ),
        ),
      if (_typeLocked)
        Text('The type can only be changed while the listing is a draft.', style: theme.textTheme.bodySmall),
      const SectionTitle('Amount', subtitle: 'Shown on the public preview.'),
      _text(
        'askingAmount',
        _funding ? 'Funding needed (PKR)' : 'Asking price (PKR)',
        icon: Icons.payments_outlined,
        keyboard: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          final n = num.tryParse(v?.trim() ?? '');
          if ((v ?? '').trim().isEmpty) return 'Amount is required';
          return n == null || n <= 0 ? 'Amount must be greater than 0' : null;
        },
      ),
    ];
  }

  List<Widget> _previewStep() {
    final theme = Theme.of(context);
    return [
      const _VisibilityBanner(confidential: false),
      _text(
        'title',
        'Title',
        icon: Icons.title,
        maxLength: 120,
        validator: Validators.requiredText('Title', min: 3, max: 120),
      ),
      _text(
        'shortDescription',
        'Short description',
        maxLines: 3,
        maxLength: 500,
        hint: 'What does the project do and who is it for?',
        validator: Validators.requiredText('Short description', min: 10, max: 500),
      ),
      _dropdown<String>(
        'Category',
        _categoryId,
        {for (final c in _categories) c.id: c.name},
        (v) => _categoryId = v,
        'categoryId',
        Icons.category_outlined,
        requiredError: 'Choose a category',
      ),
      _dropdown<String>(
        'Project stage',
        _stage,
        projectStages,
        (v) => _stage = v,
        'projectStage',
        Icons.flag_outlined,
        requiredError: 'Choose the project stage',
      ),
      TagsField(
        initial: _techStack,
        onChanged: (t) => _techStack = t,
        label: 'Tech stack (optional)',
        hint: 'e.g. Flutter, then press +',
        icon: Icons.memory,
        maxCount: 15,
        maxError: 'Add at most 15 technologies',
        maxLength: 30,
        serverError: _serverErrors['techStack'],
      ),
      const SectionTitle(
        'Photos (optional)',
        subtitle: 'Up to $maxListingPhotos photos of the device, hardware or app.',
      ),
      if (_editing)
        Text(
          'Add or remove photos on the listing page.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
        )
      else
        PhotoStrip(
          images: [for (final p in _newPhotos) MemoryImage(p.bytes)],
          onAdd: _saving ? null : _pickPhoto,
          onRemove: _saving ? null : (i) => setState(() => _newPhotos.removeAt(i)),
        ),
    ];
  }

  List<Widget> _confidentialStep() => [
    const _VisibilityBanner(confidential: true),
    if (_funding)
      _text(
        'equityOfferedPercent',
        'Equity offered (%)',
        icon: Icons.pie_chart_outline,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        validator: _equity,
      )
    else
      _text(
        'transferDetails',
        'What the buyer receives',
        maxLines: 3,
        maxLength: 2000,
        hint: 'e.g. full source code, database, documentation, 1 month support',
        validator: (v) => (v?.trim().isEmpty ?? true)
            ? 'Describe what the buyer will receive'
            : Validators.optionalText('Transfer details', max: 2000)(v),
      ),
    _text(
      'fullDescription',
      'Full description',
      maxLines: 6,
      maxLength: 5000,
      validator: Validators.requiredText('Full description', min: 20, max: 5000),
    ),
    _text(
      'problemStatement',
      'Problem statement',
      maxLines: 3,
      maxLength: 2000,
      hint: 'What problem does the project solve, and for whom?',
      validator: Validators.requiredText('Problem statement', min: 10, max: 2000),
    ),
    _text(
      'businessModel',
      'Business model',
      maxLines: 3,
      maxLength: 2000,
      hint: 'How does it earn money? e.g. subscription, one-time sale, commission',
      validator: Validators.requiredText('Business model', min: 10, max: 2000),
    ),
    _text(
      'financialSummary',
      'Financial summary',
      maxLines: 3,
      maxLength: 2000,
      hint: 'Running costs, revenue so far, or expected costs',
      validator: Validators.requiredText('Financial summary', min: 10, max: 2000),
    ),
    _text(
      'ipOwnershipNotes',
      'Ownership notes',
      maxLines: 2,
      maxLength: 1000,
      hint: 'Who owns the code and design?',
      validator: Validators.requiredText('Ownership notes', min: 10, max: 1000),
    ),
  ];

  List<Widget> _reviewStep() {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final approved = context.watch<SessionController>().user?.isApproved ?? false;
    final category = _categories.where((c) => c.id == _categoryId).firstOrNull?.name ?? 'No category yet';
    final preview = Listing(
      id: widget.listingId ?? 'draft-preview',
      listingType: _type,
      categoryId: _categoryId ?? '',
      categoryName: category,
      title: _t('title').isEmpty ? 'Untitled project' : _t('title'),
      shortDescription: _t('shortDescription').isEmpty ? 'No short description yet.' : _t('shortDescription'),
      techStack: _techStack,
      projectStage: _stage ?? '',
      askingAmount: num.tryParse(_t('askingAmount')),
      currency: 'PKR',
      coverUrl: null,
      status: 'draft',
      reviewStatus: 'unreviewed',
      ownerName: '',
    );
    final filled = [
      for (final e in confidentialLabels.entries)
        if (e.key != 'transferDetails' || !_funding) (e.value, _t(e.key).isNotEmpty),
      if (_funding) ('Equity offered', _t('equityOfferedPercent').isNotEmpty),
    ];

    return [
      const SectionTitle('How others will see it', subtitle: 'Your public preview card.'),
      IgnorePointer(
        child: ListingCard(listing: preview, onTap: () {}, showOwner: false),
      ),
      SectionTitle(
        'Confidential details',
        subtitle: 'Hidden until you approve an access request.',
        leading: Icon(Icons.lock_outline, size: IconSizes.md, color: app.verified.fg),
      ),
      AppCard(
        variant: AppCardVariant.tinted,
        role: ToneRole.verified,
        padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
        child: Column(
          children: [
            for (final (label, done) in filled)
              ListTile(
                dense: true,
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? app.approved.fg : app.borderStrong,
                  size: IconSizes.md,
                ),
                title: Text(label, style: theme.textTheme.bodyMedium),
                trailing: Text(done ? 'Added' : 'Missing', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
      const SizedBox(height: Gaps.xl),
      if (_isDraft) ...[
        AppButton(
          label: 'Save & publish',
          icon: Icons.publish,
          loading: _saving,
          onPressed: approved ? () => _save(publish: true) : null,
        ),
        const SizedBox(height: Gaps.sm),
        Text(
          approved
              ? 'Publishing sends the listing to an admin for review.'
              : 'You can publish once an admin approves your account. Save it as a draft for now.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
      const DisclaimerBanner(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: _editing ? 'Edit listing' : 'New listing',
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Skeleton(
              child: Padding(
                padding: EdgeInsets.all(Gaps.page),
                child: Column(
                  children: [
                    SkeletonBox(height: Gaps.xs),
                    SizedBox(height: Gaps.xl),
                    SkeletonBox(height: 96, radius: Radii.lg),
                    SizedBox(height: Gaps.md),
                    SkeletonBox(height: 96, radius: Radii.lg),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gaps.xl),
                child: ErrorState.from(
                  snapshot.error,
                  fallback: 'Could not load the listing.',
                  onRetry: () => setState(() => _loading = _load()),
                ),
              ),
            );
          }
          final steps = [_typeStep(), _previewStep(), _confidentialStep(), _reviewStep()];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
                    child: StepperProgress(steps: _stepTitles, current: _step, onStepTapped: _goTo),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            Visibility(
                              visible: i == _step,
                              maintainState: true,
                              child: i < _forms.length
                                  ? Form(
                                      key: _forms[i],
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: steps[i]),
                                    )
                                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: steps[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _bottomBar(),
            ],
          );
        },
      ),
    );
  }

  /// Back, Save as draft (or Save changes for a published listing) and Next. Drafts are only saved
  /// when the button is tapped; there is no autosave.
  Widget _bottomBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: AppColors.of(context).border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.md),
          child: Row(
            children: [
              if (_step > 0) ...[
                IconButton.outlined(
                  tooltip: 'Back',
                  onPressed: () => _goTo(_step - 1),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: Gaps.sm),
              ],
              Expanded(
                child: _isDraft
                    ? AppButton.secondary(
                        label: 'Save as draft',
                        loading: _saving && !_onReview,
                        onPressed: _saving ? null : _save,
                      )
                    : AppButton(label: 'Save changes', loading: _saving, onPressed: _save),
              ),
              if (!_onReview) ...[
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: _isDraft
                      ? AppButton(label: 'Next', icon: Icons.arrow_forward, onPressed: _next)
                      : AppButton.secondary(label: 'Next', onPressed: _next),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains who sees a step's fields: the public preview (eye, cobalt) or the confidential
/// details (lock, tinted), so the separation is obvious while filling them in.
class _VisibilityBanner extends StatelessWidget {
  const _VisibilityBanner({required this.confidential});

  final bool confidential;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Gaps.md),
    child: confidential
        ? const AppBanner(
            icon: Icons.lock_outline,
            role: ToneRole.verified,
            title: 'Confidential · only you',
            message:
                'Stored separately from the preview. Investors or buyers see these only after you approve '
                'their access request.',
          )
        : const AppBanner(
            icon: Icons.visibility_outlined,
            role: ToneRole.neutral,
            title: 'Public preview · everyone',
            message: 'Shown to investors and buyers when they browse. Keep secrets for the next step.',
          ),
  );
}

/// One of the two listing types as a large selectable card in its own colour.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.isFunding,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final bool isFunding;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final tone = app.listingType(isFunding: isFunding);
    final duration = Motion.of(context, Motion.base);
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      child: AnimatedContainer(
        duration: duration,
        curve: Motion.standard,
        decoration: BoxDecoration(
          color: selected ? tone.bg : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: selected ? tone.fg : app.border,
            width: selected ? Sizes.focusRing : Sizes.hairline,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Padding(
              padding: const EdgeInsets.all(Gaps.lg),
              child: Row(
                children: [
                  Container(
                    width: Sizes.tapTarget,
                    height: Sizes.tapTarget,
                    decoration: BoxDecoration(
                      color: selected ? theme.colorScheme.surface : tone.bg,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Icon(isFunding ? Icons.trending_up : Icons.sell_outlined, color: tone.fg),
                  ),
                  const SizedBox(width: Gaps.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: Gaps.xxs),
                        Text(body, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? tone.fg : app.borderStrong,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
