import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../auth/session/session_controller.dart';
import '../../auth/widgets/form_widgets.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/widgets/profile_fields.dart';
import '../data/listing_api.dart';
import '../data/listing_models.dart';
import '../widgets/listing_widgets.dart';

/// Create a listing (no [listingId]) or edit one. Rules match backend/src/modules/listings/listing.validation.js.
/// The public preview and the confidential details are separate sections, as they are stored separately.
/// A draft can be saved as is, or saved and published (sent for admin review) in one step.
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, this.listingId});

  final String? listingId;

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};

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

  Future<void> _pickPhoto() async {
    final choice = await pickImage(context, canRemove: false);
    if (choice is PickedImage && mounted) setState(() => _newPhotos.add(choice.file));
  }

  // Photos are uploaded before publishing, so adding them does not send a just-published listing back to review.
  Future<void> _save({bool publish = false}) async {
    setState(() => _serverErrors = const {});
    if (!_form.currentState!.validate()) {
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
      showInfoSnack(
        context,
        publish
            ? 'Listing published. It is visible to others once an admin approves it.'
            : _editing
            ? 'Listing saved'
            : 'Draft saved. You can publish it from the listing page.',
      );
      _editing ? context.pop(true) : context.pushReplacement(Routes.listing(id));
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
        showInfoSnack(context, e.message);
      } else {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _ctl(key),
      validator: validator,
      forceErrorText: _serverErrors[key],
      maxLines: maxLines,
      minLines: maxLines > 1 ? 2 : 1,
      maxLength: maxLength,
      keyboardType: keyboard ?? (maxLines > 1 ? TextInputType.multiline : null),
      inputFormatters: formatters,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
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
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) => setState(() => onChanged(v)),
      validator: (v) => v == null ? requiredError : null,
      forceErrorText: _serverErrors[errorKey],
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
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

  // Drafts: "Save as draft" and "Save & publish". A published listing: "Save changes" (it goes back to review).
  List<Widget> _buttons() {
    if (!_isDraft) return [LoadingButton(label: 'Save changes', loading: _saving, onPressed: _save)];
    final approved = context.watch<SessionController>().user?.isApproved ?? false;
    return [
      LoadingButton(label: 'Save & publish', loading: _saving, onPressed: approved ? () => _save(publish: true) : null),
      if (!approved)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'You can publish once an admin approves your account. Save it as a draft for now.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _saving ? null : _save, child: const Text('Save as draft')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit listing' : 'New listing')),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load the listing.'),
                  TextButton(onPressed: () => setState(() => _loading = _load()), child: const Text('Try again')),
                ],
              ),
            );
          }
          return Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Listing type'),
                  SegmentedButton<String>(
                    segments: [
                      for (final e in listingTypeLabels.entries)
                        ButtonSegment(
                          value: e.key,
                          label: Text(e.value, textAlign: TextAlign.center),
                          icon: Icon(e.key == 'funding' ? Icons.trending_up : Icons.sell_outlined),
                        ),
                    ],
                    selected: {_type},
                    onSelectionChanged: _typeLocked ? null : (s) => setState(() => _type = s.first),
                  ),
                  if (_typeLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'The type can only be changed while the listing is a draft.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SectionTitle(
                    'Public preview',
                    subtitle: 'Shown to investors and buyers when they browse. Keep secrets out of it.',
                  ),
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
                  const SizedBox(height: 16),
                  Text('Photos (optional)', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Up to $maxListingPhotos photos of the device, hardware or app screens.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (_editing)
                    Text(
                      'Add or remove photos on the listing page.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.primary),
                    )
                  else
                    PhotoStrip(
                      images: [for (final p in _newPhotos) MemoryImage(p.bytes)],
                      onAdd: _saving ? null : _pickPhoto,
                      onRemove: _saving ? null : (i) => setState(() => _newPhotos.removeAt(i)),
                    ),
                  const SizedBox(height: 20),
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
                  const SectionTitle('Confidential details'),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: colors.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: colors.onTertiaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Stored separately and visible only to you. Later you decide which approved '
                            'investors or buyers may see them.',
                            style: TextStyle(color: colors.onTertiaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  const SizedBox(height: 8),
                  ..._buttons(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
