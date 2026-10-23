import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../auth/session/session_controller.dart';
import '../../auth/widgets/form_widgets.dart';
import '../data/profile_api.dart';
import '../data/profile_models.dart';
import '../widgets/profile_fields.dart';

/// Profile form for owners, investors and buyers.
/// [setup] = first time after sign-up (no back button, goes home after saving).
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.setup = false});

  final bool setup;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{}; // one controller per text field, keyed by API name

  late Future<void> _loading;
  List<Category> _categories = const [];
  List<String> _skills = [];
  Set<String> _interests = {};
  String? _type; // investorType / buyerType
  String _currency = 'PKR';
  bool _saving = false;
  Map<String, String> _serverErrors = const {};
  String? _avatarUrl;
  bool _avatarBusy = false;

  String get _role => context.read<SessionController>().user!.role;

  TextEditingController _ctl(String key) => _c.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<void> _load() async {
    final api = context.read<ProfileApi>();
    final results = await Future.wait([api.getMine(), api.categories()]);
    final profile = results[0] as MyProfile;
    _categories = results[1] as List<Category>;

    _ctl('fullName').text = profile.fullName;
    _ctl('headline').text = profile.headline ?? '';
    _ctl('city').text = profile.city ?? '';
    _ctl('bio').text = profile.bio ?? '';
    _ctl('linkedinUrl').text = profile.linkedinUrl ?? '';
    _ctl('websiteUrl').text = profile.websiteUrl ?? '';
    for (final key in [
      'university',
      'degreeProgram',
      'githubUrl',
      'portfolioUrl',
      'organizationName',
      'companyName',
      'companyWebsite',
    ]) {
      _ctl(key).text = profile.detailText(key) ?? '';
    }
    for (final key in ['graduationYear', 'minTicket', 'maxTicket', 'budgetMin', 'budgetMax']) {
      final n = profile.detailNumber(key);
      _ctl(key).text = n == null ? '' : (n % 1 == 0 ? n.toInt().toString() : n.toString());
    }
    _skills = profile.skills;
    _interests = profile.interestIds;
    _type = profile.detailText(_role == 'investor' ? 'investorType' : 'buyerType');
    _currency = profile.detailText('currency') ?? 'PKR';
    _avatarUrl = profile.avatarUrl;
  }

  // The photo is saved straight away, separately from the rest of the form.
  Future<void> _changeAvatar() async {
    final choice = await pickImage(context, canRemove: _avatarUrl != null);
    if (choice == null || !mounted) return;
    final api = context.read<ProfileApi>();
    setState(() => _avatarBusy = true);
    try {
      final profile = switch (choice) {
        PickedImage(:final path) => await api.setAvatar(path),
        RemoveImage() => await api.removeAvatar(),
      };
      if (mounted) setState(() => _avatarUrl = profile.avatarUrl);
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String key) => _ctl(key).text.trim();
  num? _n(String key) => num.tryParse(_t(key));

  Map<String, dynamic> _body() => {
    'fullName': _t('fullName'),
    'headline': _t('headline'),
    'city': _t('city'),
    'bio': _t('bio'),
    'linkedinUrl': _t('linkedinUrl'),
    'websiteUrl': _t('websiteUrl'),
    'details': switch (_role) {
      'owner' => {
        'university': _t('university'),
        'degreeProgram': _t('degreeProgram'),
        'graduationYear': _n('graduationYear')?.toInt(),
        'skills': _skills,
        'githubUrl': _t('githubUrl'),
        'portfolioUrl': _t('portfolioUrl'),
      },
      'investor' => {
        'investorType': _type,
        'organizationName': _t('organizationName'),
        'minTicket': _n('minTicket'),
        'maxTicket': _n('maxTicket'),
        'currency': _currency,
        'interests': _interests.toList(),
      },
      _ => {
        'buyerType': _type,
        'companyName': _t('companyName'),
        'companyWebsite': _t('companyWebsite'),
        'budgetMin': _n('budgetMin'),
        'budgetMax': _n('budgetMax'),
        'currency': _currency,
        'interests': _interests.toList(),
      },
    },
  };

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    if (!_form.currentState!.validate()) {
      showInfoSnack(context, 'Please correct the highlighted fields');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await context.read<ProfileApi>().saveMine(_body());
      if (!mounted) return;
      final session = context.read<SessionController>();
      session.updateUser(session.user!.copyWith(fullName: saved.fullName, profileCompleted: true));
      showInfoSnack(context, widget.setup ? 'Profile completed. Welcome to Orwickle!' : 'Profile saved');
      widget.setup ? context.go(Routes.home) : Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        // the API names role fields "details.university"; the form uses "university"
        setState(
          () => _serverErrors = {
            for (final entry in e.fieldErrors.entries) entry.key.replaceFirst('details.', ''): entry.value,
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

  // ---------- form pieces ----------

  Widget _text(
    String key,
    String label, {
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int maxLines = 1,
    String? hint,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _ctl(key),
      validator: validator,
      forceErrorText: _serverErrors[key],
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLines: maxLines,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: icon == null ? null : Icon(icon)),
    ),
  );

  // "an Investor", "a Buyer"
  static String _withArticle(String noun) => '${RegExp('^[AEIOU]').hasMatch(noun) ? 'an' : 'a'} $noun';

  // [label] is the short text on the field; [errorLabel] names it in error messages
  Widget _money(String key, String label, String errorLabel, {String? Function(String?)? validator}) => Expanded(
    child: _text(
      key,
      label,
      keyboard: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator ?? Validators.amount(errorLabel),
    ),
  );

  Widget _typeDropdown(String label, Map<String, String> options, String errorKey) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: options.containsKey(_type) ? _type : null,
      items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) => setState(() => _type = v),
      validator: (v) => v == null ? 'Choose $label' : null,
      forceErrorText: _serverErrors[errorKey],
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.badge_outlined)),
    ),
  );

  Widget _currencyAndRange(String minKey, String maxKey, String minLabel, String maxLabel, String rangeName) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SegmentedButton<String>(
          segments: [for (final c in currencies) ButtonSegment(value: c, label: Text(c))],
          selected: {_currency},
          onSelectionChanged: (s) => setState(() => _currency = s.first),
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _money(minKey, 'Minimum ($_currency)', minLabel),
          const SizedBox(width: 12),
          _money(
            maxKey,
            'Maximum ($_currency)',
            maxLabel,
            validator: Validators.rangeMax(maxLabel, () => _ctl(minKey).text, rangeName),
          ),
        ],
      ),
    ],
  );

  List<Widget> _roleSection() => switch (_role) {
    'owner' => [
      const SectionTitle('Education & skills', subtitle: 'Helps investors and buyers trust your work'),
      _text(
        'university',
        'University',
        icon: Icons.school_outlined,
        validator: Validators.requiredText('University', max: 150),
      ),
      _text(
        'degreeProgram',
        'Degree program',
        icon: Icons.menu_book_outlined,
        hint: 'e.g. BS Computer Science',
        validator: Validators.requiredText('Degree program', max: 100),
      ),
      _text(
        'graduationYear',
        'Graduation year (optional)',
        icon: Icons.event_outlined,
        keyboard: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        validator: Validators.graduationYear,
      ),
      TagsField(
        initial: _skills,
        onChanged: (s) => _skills = s,
        label: 'Skills',
        hint: 'e.g. Flutter, then press +',
        icon: Icons.psychology_outlined,
        emptyError: 'Add at least one skill',
        maxCount: 20,
        maxError: 'Add at most 20 skills',
        serverError: _serverErrors['skills'],
      ),
      const SizedBox(height: 16),
      _text(
        'githubUrl',
        'GitHub (optional)',
        icon: Icons.code,
        keyboard: TextInputType.url,
        hint: 'https://github.com/username',
        validator: Validators.optionalUrl('GitHub URL'),
      ),
      _text(
        'portfolioUrl',
        'Portfolio (optional)',
        icon: Icons.web_outlined,
        keyboard: TextInputType.url,
        validator: Validators.optionalUrl('portfolio URL'),
      ),
    ],
    'investor' => [
      const SectionTitle('Investment preferences'),
      _typeDropdown('Investor type', investorTypes, 'investorType'),
      _text(
        'organizationName',
        'Organization (optional)',
        icon: Icons.business_outlined,
        validator: Validators.optionalText('Organization name', max: 150),
      ),
      _currencyAndRange('minTicket', 'maxTicket', 'Minimum investment', 'Maximum investment', 'investment'),
      const SectionTitle('Interested categories', subtitle: 'Choose up to 10'),
      InterestsField(
        categories: _categories,
        initial: _interests,
        onChanged: (s) => _interests = s,
        serverError: _serverErrors['interests'],
      ),
    ],
    _ => [
      const SectionTitle('Buyer details'),
      _typeDropdown('Buyer type', buyerTypes, 'buyerType'),
      _text(
        'companyName',
        'Company (optional)',
        icon: Icons.business_outlined,
        validator: Validators.optionalText('Company name', max: 150),
      ),
      _text(
        'companyWebsite',
        'Company website (optional)',
        icon: Icons.language,
        keyboard: TextInputType.url,
        validator: Validators.optionalUrl('company website'),
      ),
      _currencyAndRange('budgetMin', 'budgetMax', 'Minimum budget', 'Maximum budget', 'budget'),
      const SectionTitle('Interested categories', subtitle: 'Choose up to 10'),
      InterestsField(
        categories: _categories,
        initial: _interests,
        onChanged: (s) => _interests = s,
        serverError: _serverErrors['interests'],
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.setup,
        title: Text(widget.setup ? 'Complete your profile' : 'Edit profile'),
        actions: [
          if (widget.setup)
            IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout), onPressed: () => session.logout()),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error! as ApiException).message
                : 'Could not load your profile.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(() => _loading = _load()), child: const Text('Try again')),
                  ],
                ),
              ),
            );
          }
          // SingleChildScrollView (not ListView) keeps every field built, so validate() checks
          // fields that are scrolled out of view too
          return Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.setup)
                    InfoBanner(
                      icon: Icons.waving_hand_outlined,
                      message:
                          'Welcome, ${session.user?.fullName ?? ''}! Tell others a little about yourself '
                          'as ${_withArticle(session.user?.roleLabel ?? '')}.',
                    ),
                  Center(
                    child: Stack(
                      children: [
                        UserAvatar(radius: 48, url: _avatarUrl, initials: session.user?.initials ?? '?'),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filled(
                            tooltip: 'Change photo',
                            onPressed: _avatarBusy ? null : _changeAvatar,
                            icon: _avatarBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.photo_camera_outlined, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SectionTitle('About you'),
                  _text(
                    'fullName',
                    'Full name',
                    icon: Icons.person_outline,
                    validator: Validators.requiredText('Full name', max: 100),
                  ),
                  _text(
                    'headline',
                    'Headline',
                    icon: Icons.short_text,
                    hint: _role == 'owner' ? 'e.g. CS student building EdTech apps' : 'e.g. Angel investor in FinTech',
                    validator: Validators.requiredText('Headline', max: 150),
                  ),
                  _text(
                    'city',
                    'City',
                    icon: Icons.location_city_outlined,
                    validator: Validators.requiredText('City', max: 80),
                  ),
                  _text('bio', 'Bio (optional)', maxLines: 4, validator: Validators.optionalText('Bio', max: 2000)),
                  _text(
                    'linkedinUrl',
                    'LinkedIn (optional)',
                    icon: Icons.link,
                    keyboard: TextInputType.url,
                    hint: 'https://www.linkedin.com/in/...',
                    validator: Validators.optionalUrl('LinkedIn URL'),
                  ),
                  _text(
                    'websiteUrl',
                    'Website (optional)',
                    icon: Icons.language,
                    keyboard: TextInputType.url,
                    validator: Validators.optionalUrl('website URL'),
                  ),
                  ..._roleSection(),
                  const SizedBox(height: 24),
                  LoadingButton(label: widget.setup ? 'Save and continue' : 'Save', loading: _saving, onPressed: _save),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
