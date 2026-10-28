import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../auth/session/session_controller.dart';
import '../../auth/widgets/form_widgets.dart';
import '../data/profile_api.dart';
import '../data/profile_models.dart';
import '../widgets/document_field.dart';
import '../widgets/profile_fields.dart';

/// Profile form for owners, investors and buyers, in four steps (about you, role details,
/// skills or interests, verification). The fields follow
/// backend/src/modules/profiles/profile.validation.js:
///  - owner: headline, bio, links, education, skills + university ID card
///  - investor: phone, LinkedIn, CNIC (+ photos), type, experience, range, interests; company details for firms
///  - buyer: type, university or company (company name / university ID card), interests
/// Documents and the photo are uploaded as soon as they are picked; the rest is saved with the button.
/// [setup] = first time after sign-up (no back button, goes home after saving).
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.setup = false});

  final bool setup;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _forms = List.generate(4, (_) => GlobalKey<FormState>()); // one form per step
  final _scroll = ScrollController();
  int _step = 0;
  final _c = <String, TextEditingController>{}; // one controller per text field, keyed by API name

  late Future<void> _loading;
  List<Category> _categories = const [];
  List<String> _skills = [];
  Set<String> _interests = {};
  String? _type; // investorType / buyerType
  String? _experience; // investor
  String? _affiliation; // buyer: university | company
  String? _ownerKind; // owner: student | independent
  AmountRange? _range; // investor ticket size
  Map<String, ProfileDocument> _documents = {};
  bool _saving = false;
  Map<String, String> _serverErrors = const {};
  String? _avatarUrl;
  bool _avatarBusy = false;

  String get _role => context.read<SessionController>().user!.role;
  bool get _isFirm => _type == 'firm';
  bool get _isStudent => _ownerKind == 'student';

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
    _ctl('city').text = profile.city ?? '';
    _ctl('headline').text = profile.headline ?? '';
    _ctl('bio').text = profile.bio ?? '';
    _ctl('linkedinUrl').text = profile.linkedinUrl ?? '';
    _ctl('websiteUrl').text = profile.websiteUrl ?? '';
    _ctl('phone').text = profile.phone ?? '';
    for (final key in [
      'university',
      'degreeProgram',
      'githubUrl',
      'portfolioUrl',
      'companyName',
      'companyWebsite',
      'companyEmail',
      'professionalAffiliation',
      'investmentHistory',
    ]) {
      _ctl(key).text = profile.detailText(key) ?? '';
    }
    _ctl('cnicNumber').text = formatCnic(profile.detailText('cnicNumber'));
    final isStudent = profile.details['isStudent'] as bool?;
    // a new owner has not chosen yet
    _ownerKind = !profile.completed || isStudent == null ? null : (isStudent ? 'student' : 'independent');
    _skills = profile.skills;
    _interests = profile.interestIds;
    _type = profile.detailText(_role == 'investor' ? 'investorType' : 'buyerType');
    _experience = profile.detailText('investmentExperience');
    _affiliation = profile.detailText('affiliation');
    _range = AmountRange.match(profile.detailNumber('minTicket'), profile.detailNumber('maxTicket'));
    _documents = {for (final d in profile.documents) d.kind: d};
    _avatarUrl = profile.avatarUrl;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    if (_forms[_step].currentState!.validate()) _goTo(_step + 1);
  }

  /// Checks every step and opens the first one with a problem; null when all are fine.
  int? _firstInvalidStep() {
    int? first;
    for (var i = 0; i < _forms.length; i++) {
      final valid = _forms[i].currentState?.validate() ?? true; // validate all so every error shows
      if (!valid) first ??= i;
    }
    return first;
  }

  String _t(String key) => _ctl(key).text.trim();

  Map<String, dynamic> _body() => switch (_role) {
    'owner' => {
      'fullName': _t('fullName'),
      'headline': _t('headline'),
      'bio': _t('bio'),
      'linkedinUrl': _t('linkedinUrl'),
      'websiteUrl': _t('websiteUrl'),
      'details': {
        'isStudent': _ownerKind == null ? null : _isStudent,
        'university': _isStudent ? _t('university') : null,
        'degreeProgram': _isStudent ? _t('degreeProgram') : null,
        'skills': _skills,
        'githubUrl': _t('githubUrl'),
        'portfolioUrl': _t('portfolioUrl'),
      },
    },
    'investor' => {
      'fullName': _t('fullName'),
      'city': _t('city'),
      'phone': Validators.normalizePhone(_t('phone')),
      'linkedinUrl': _t('linkedinUrl'),
      'websiteUrl': _t('websiteUrl'),
      'details': {
        'investorType': _type,
        'cnicNumber': _t('cnicNumber'),
        'companyName': _t('companyName'),
        'companyWebsite': _t('companyWebsite'),
        'companyEmail': _t('companyEmail'),
        'investmentExperience': _experience,
        'professionalAffiliation': _t('professionalAffiliation'),
        'investmentHistory': _experience == 'first_time' ? null : _t('investmentHistory'),
        'portfolioUrl': _t('portfolioUrl'),
        'minTicket': _range?.min,
        'maxTicket': _range?.max,
        'interests': _interests.toList(),
      },
    },
    _ => {
      'fullName': _t('fullName'),
      'city': _t('city'),
      'phone': Validators.normalizePhone(_t('phone')),
      'linkedinUrl': _t('linkedinUrl'),
      'details': {
        'buyerType': _type,
        'affiliation': _affiliation,
        'companyName': _affiliation == 'company' ? _t('companyName') : null,
        'companyEmail': _affiliation == 'company' ? _t('companyEmail') : null,
        'interests': _interests.toList(),
      },
    },
  };

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    final invalid = _firstInvalidStep();
    if (invalid != null) {
      _goTo(invalid);
      showInfoSnack(context, 'Please correct the highlighted fields');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await context.read<ProfileApi>().saveMine(_body());
      if (!mounted) return;
      final session = context.read<SessionController>();
      session.updateUser(
        session.user!.copyWith(
          fullName: saved.fullName,
          profileCompleted: true,
          approvalStatus: saved.reviewStatus,
          approvalNote: saved.reviewNote,
        ),
      );
      showInfoSnack(
        context,
        saved.reviewStatus == 'pending' ? 'Profile saved and sent to an admin for approval' : 'Profile saved',
      );
      widget.setup ? context.go(Routes.home) : Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        // the API names role fields "details.university" and documents "documents.cnic_front"
        setState(
          () => _serverErrors = {
            for (final entry in e.fieldErrors.entries)
              entry.key.replaceFirst('details.', '').replaceFirst('documents.', ''): entry.value,
          },
        );
        // once the fields show the server's messages, open the first step that has one
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final invalid = mounted ? _firstInvalidStep() : null;
          if (invalid != null) _goTo(invalid);
        });
        showInfoSnack(context, e.message);
      } else {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // The photo is saved straight away, separately from the rest of the form.
  Future<void> _changeAvatar() async {
    final choice = await pickImage(context, canRemove: _avatarUrl != null);
    if (choice == null || !mounted) return;
    final api = context.read<ProfileApi>();
    setState(() => _avatarBusy = true);
    try {
      final profile = switch (choice) {
        PickedImage(:final file) => await api.setAvatar(file),
        RemoveImage() => await api.removeAvatar(),
      };
      if (mounted) setState(() => _avatarUrl = profile.avatarUrl);
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
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

  Widget _dropdown(
    String label,
    String? value,
    Map<String, String> options,
    ValueChanged<String?> onChanged, {
    required String errorKey,
    required String requiredError,
    IconData icon = Icons.badge_outlined,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) => setState(() => onChanged(v)),
      validator: (v) => v == null ? requiredError : null,
      forceErrorText: _serverErrors[errorKey],
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );

  Widget _document(String kind, String label, {bool required = true}) => DocumentField(
    key: ValueKey(kind),
    label: label,
    initial: _documents[kind],
    required: required,
    serverError: _serverErrors[kind],
    onUpload: (file) async {
      final profile = await context.read<ProfileApi>().uploadDocument(kind, file);
      _documents = {for (final d in profile.documents) d.kind: d};
      return _documents[kind];
    },
    onRemove: () async {
      final profile = await context.read<ProfileApi>().removeDocument(kind);
      _documents = {for (final d in profile.documents) d.kind: d};
    },
  );

  Widget _interestsField() => InterestsField(
    categories: _categories,
    initial: _interests,
    onChanged: (s) => _interests = s,
    serverError: _serverErrors['interests'],
  );

  // ---------- steps ----------

  /// The four steps for the user's role. Every step is its own form, so "Next" checks one step
  /// and saving checks them all.
  List<_ProfileStep> _steps() => switch (_role) {
    'owner' => [
      _ProfileStep('About you', [..._aboutYou(), ..._ownerAbout()]),
      _ProfileStep('Background', _ownerBackground()),
      _ProfileStep('Skills & work', _ownerWork()),
      _ProfileStep('Verification', _ownerVerification()),
    ],
    'investor' => [
      _ProfileStep('About you', [..._aboutYou(), ..._contactFields(), _investorWebsite()]),
      _ProfileStep('Investing', _investorDetails()),
      _ProfileStep('Interests', _interestsStep()),
      _ProfileStep('Verification', _investorVerification()),
    ],
    _ => [
      _ProfileStep('About you', [..._aboutYou(), ..._contactFields()]),
      _ProfileStep('Buyer details', _buyerDetails()),
      _ProfileStep('Interests', _interestsStep()),
      _ProfileStep('Verification', _buyerVerification()),
    ],
  };

  /// Photo, name and (for investors and buyers) city: the start of every role's first step.
  List<Widget> _aboutYou() {
    final session = context.watch<SessionController>();
    return [
      if (widget.setup)
        InfoBanner(
          icon: Icons.waving_hand_outlined,
          message:
              'Welcome, ${session.user?.fullName ?? ''}! Complete your profile in four short steps — an admin '
              'reviews it before you get full access.',
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.photo_camera_outlined, size: 20),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Gaps.xl),
      _text(
        'fullName',
        'Full name',
        icon: Icons.person_outline,
        validator: Validators.requiredText('Full name', max: 100),
      ),
      if (_role != 'owner')
        _text('city', 'City', icon: Icons.location_city_outlined, validator: Validators.requiredText('City', max: 80)),
    ];
  }

  List<Widget> _interestsStep() => [
    const SectionTitle('Interested categories', subtitle: 'Choose up to 10'),
    _interestsField(),
  ];

  /// Shown on the last step while the documents depend on a choice made in an earlier step.
  Widget _chooseFirst(String text) => InfoBanner(icon: Icons.arrow_back, message: text);

  List<Widget> _ownerAbout() => [
    _text(
      'headline',
      'Headline',
      icon: Icons.short_text,
      hint: 'e.g. CS student building EdTech apps',
      validator: Validators.requiredText('Headline', max: 150),
    ),
    _text(
      'bio',
      'Bio',
      maxLines: 4,
      hint: 'A few lines about you and what you build',
      validator: Validators.requiredText('Bio', min: 10, max: 2000),
    ),
    _text(
      'linkedinUrl',
      'LinkedIn profile',
      icon: Icons.link,
      keyboard: TextInputType.url,
      hint: 'https://www.linkedin.com/in/...',
      validator: Validators.requiredUrl('LinkedIn profile'),
    ),
    _text(
      'websiteUrl',
      'Website (optional)',
      icon: Icons.language,
      keyboard: TextInputType.url,
      validator: Validators.optionalUrl('website URL'),
    ),
  ];

  List<Widget> _ownerBackground() => [
    const SectionTitle('Your background', subtitle: 'Anyone can list a project, at a university or self-taught'),
    _choice(
      _ownerKind,
      ownerKinds,
      const {'student': Icons.school_outlined, 'independent': Icons.laptop_outlined},
      (v) => _ownerKind = v,
      'Choose whether you are a university student',
      errorKey: 'isStudent',
    ),
    if (_isStudent) ...[
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
    ],
  ];

  List<Widget> _ownerWork() => [
    const SectionTitle('Skills & work', subtitle: 'Helps investors and buyers trust your work'),
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
      'GitHub profile',
      icon: Icons.code,
      keyboard: TextInputType.url,
      hint: 'https://github.com/username',
      validator: Validators.requiredUrl('GitHub profile'),
    ),
    _text(
      'portfolioUrl',
      'Portfolio link',
      icon: Icons.web_outlined,
      keyboard: TextInputType.url,
      hint: 'Your portfolio site, Behance or a project demo',
      validator: Validators.requiredUrl('Portfolio link'),
    ),
  ];

  List<Widget> _ownerVerification() => [
    const SectionTitle('Verification'),
    if (_isStudent) ...[
      const PrivacyNote(
        'Your university ID card is used only to verify you are a student. Only Orwickle admins can see it.',
      ),
      _document('university_id_front', 'the front of your university ID card'),
      _document('university_id_back', 'the back of your university ID card'),
    ] else if (_ownerKind == 'independent') ...[
      const PrivacyNote(
        'Your CNIC is used only to verify your identity. It is stored privately and only Orwickle admins can see it.',
      ),
      _document('cnic_front', 'the front of your CNIC'),
      _document('cnic_back', 'the back of your CNIC'),
    ] else
      _chooseFirst(
        'Choose your background in step 2 first. Students upload their university ID card, '
        'independent developers their CNIC.',
      ),
  ];

  // investors and buyers
  List<Widget> _contactFields() => [
    _text(
      'phone',
      'Phone number',
      icon: Icons.phone_outlined,
      keyboard: TextInputType.phone,
      hint: '03001234567',
      validator: Validators.phone,
    ),
    _text(
      'linkedinUrl',
      'LinkedIn profile',
      icon: Icons.link,
      keyboard: TextInputType.url,
      hint: 'https://www.linkedin.com/in/...',
      validator: Validators.requiredUrl('LinkedIn profile'),
    ),
  ];

  Widget _investorWebsite() => _text(
    'websiteUrl',
    'Website (optional)',
    icon: Icons.language,
    keyboard: TextInputType.url,
    hint: 'Your personal or professional website',
    validator: Validators.optionalUrl('website URL'),
  );

  List<Widget> _investorDetails() => [
    const SectionTitle('Investor details'),
    _dropdown(
      'Investor type',
      _type,
      investorTypes,
      (v) => _type = v,
      errorKey: 'investorType',
      requiredError: 'Choose an investor type',
    ),
    _dropdown(
      'Investment experience',
      _experience,
      investmentExperiences,
      (v) => _experience = v,
      errorKey: 'investmentExperience',
      requiredError: 'Choose your investment experience',
      icon: Icons.timeline,
    ),
    _text(
      'professionalAffiliation',
      'Professional affiliation',
      icon: Icons.work_outline,
      hint: 'e.g. Manager at HBL; member of an angel network',
      validator: Validators.requiredText('Professional affiliation', max: 300),
    ),
    if (_experience != null && _experience != 'first_time')
      _text(
        'investmentHistory',
        'Investment history',
        maxLines: 4,
        hint: 'Which startups did you invest in, when, and how much (roughly)?',
        validator: (v) => (v?.trim().length ?? 0) < 10
            ? 'Describe your past investments'
            : Validators.optionalText('Investment history', max: 2000)(v),
      ),
    _text(
      'portfolioUrl',
      'Investment portfolio (optional)',
      icon: Icons.pie_chart_outline,
      keyboard: TextInputType.url,
      hint: 'Link to your portfolio, e.g. AngelList or a website',
      validator: Validators.optionalUrl('portfolio URL'),
    ),
    RangeChipsField(
      label: 'How much do you usually invest in one project? (PKR)',
      initial: _range,
      required: true,
      requiredError: 'Choose an investment range',
      onChanged: (r) => _range = r,
      serverError: _serverErrors['minTicket'] ?? _serverErrors['maxTicket'],
    ),
    if (_isFirm) ...[
      const SectionTitle('Company', subtitle: 'Required for investment firms'),
      _text(
        'companyName',
        'Company name',
        icon: Icons.business_outlined,
        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Company name is required for investment firms' : null,
      ),
      _text(
        'companyWebsite',
        'Company website',
        icon: Icons.language,
        keyboard: TextInputType.url,
        validator: (v) => (v?.trim().isEmpty ?? true)
            ? 'Company website is required for investment firms'
            : Validators.optionalUrl('company website')(v),
      ),
      _text(
        'companyEmail',
        'Company email',
        icon: Icons.alternate_email,
        keyboard: TextInputType.emailAddress,
        validator: Validators.companyEmail(required: () => _isFirm),
      ),
    ],
  ];

  List<Widget> _investorVerification() => [
    const SectionTitle('Identity verification'),
    const PrivacyNote(
      'Your CNIC is used only to verify your identity. It is stored privately and only Orwickle admins can see it.',
    ),
    _text(
      'cnicNumber',
      'CNIC number',
      icon: Icons.badge_outlined,
      keyboard: TextInputType.number,
      hint: '42101-1234567-1',
      formatters: [CnicInputFormatter()],
      validator: Validators.cnic,
    ),
    _document('cnic_front', 'the front of your CNIC'),
    _document('cnic_back', 'the back of your CNIC'),
    if (_type != null) ...[
      SectionTitle(
        _isFirm ? 'Company verification' : 'Proof of funds',
        subtitle: _isFirm
            ? 'Shows that the company is registered'
            : 'Shows that you can invest the amount you chose. You may cover account numbers.',
      ),
      if (_isFirm)
        _document('company_certificate', 'your company registration certificate')
      else
        _document('funds_proof', 'proof of funds (bank statement, bank letter or tax return)'),
    ],
    if (_experience != null && _experience != 'first_time') ...[
      const SectionTitle(
        'Investment experience proof',
        subtitle: 'One past investment: share certificate, investment agreement or a letter from the startup',
      ),
      _document('investment_proof', 'proof of a past investment'),
    ],
    if (_type == null) _chooseFirst('Choose your investor type in step 2 to see which other documents you need.'),
  ];

  /// Two or more mutually exclusive options as a segmented button that takes part in form validation.
  Widget _choice(
    String? value,
    Map<String, String> options,
    Map<String, IconData> icons,
    ValueChanged<String?> onChanged,
    String requiredError, {
    required String errorKey,
  }) => FormField<String>(
    initialValue: value,
    validator: (_) => value == null ? requiredError : null,
    forceErrorText: _serverErrors[errorKey],
    builder: (state) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          segments: [
            for (final e in options.entries)
              ButtonSegment(
                value: e.key,
                label: Text(e.value, textAlign: TextAlign.center),
                icon: Icon(icons[e.key]),
              ),
          ],
          selected: {?value},
          onSelectionChanged: (s) {
            final picked = s.isEmpty ? null : s.first;
            setState(() => onChanged(picked));
            state.didChange(picked);
          },
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(state.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
        const SizedBox(height: 16),
      ],
    ),
  );

  List<Widget> _buyerDetails() => [
    const SectionTitle('Buyer details'),
    _dropdown(
      'Buyer type',
      _type,
      buyerTypes,
      (v) => _type = v,
      errorKey: 'buyerType',
      requiredError: 'Choose a buyer type',
    ),
    Text('Are you buying as a student or for a company?', style: Theme.of(context).textTheme.bodyMedium),
    const SizedBox(height: 8),
    _choice(
      _affiliation,
      affiliations,
      const {'university': Icons.school_outlined, 'company': Icons.business_outlined},
      (v) => _affiliation = v,
      'Choose University or Company',
      errorKey: 'affiliation',
    ),
    if (_affiliation == 'company') ...[
      _text(
        'companyName',
        'Company name',
        icon: Icons.business_outlined,
        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Company name is required' : null,
      ),
      _text(
        'companyEmail',
        'Company email',
        icon: Icons.alternate_email,
        keyboard: TextInputType.emailAddress,
        validator: Validators.companyEmail(required: () => true, requiredMessage: 'Company email is required'),
      ),
    ],
  ];

  List<Widget> _buyerVerification() => [
    const SectionTitle('Verification'),
    if (_affiliation == 'university') ...[
      const PrivacyNote('Your university ID card is used only to verify you. Only Orwickle admins can see it.'),
      _document('university_id_front', 'the front of your university ID card'),
      _document('university_id_back', 'the back of your university ID card'),
    ] else if (_affiliation == 'company')
      const InfoBanner(icon: Icons.check_circle_outline, message: 'No documents are needed when you buy for a company.')
    else
      _chooseFirst('Choose University or Company in step 2 first.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.setup,
        title: Text(widget.setup ? 'Complete your profile' : 'Edit profile'),
        actions: [
          if (widget.setup)
            IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout), onPressed: () => confirmLogout(context)),
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
          final steps = _steps();
          final isLast = _step == steps.length - 1;
          return Column(
            children: [
              _StepHeader(steps: steps, current: _step, onTap: _goTo),
              Expanded(
                // every step stays built (only the current one is visible), so saving can check them all
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.sm, Gaps.xl, Gaps.xl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            Visibility(
                              visible: i == _step,
                              maintainState: true,
                              child: Form(
                                key: _forms[i],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: steps[i].fields,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _bottomBar(isLast),
            ],
          );
        },
      ),
    );
  }

  /// Setup: Back + Next, and "Submit for review" on the last step.
  /// Editing: Save is always there, so a small change does not need all four steps.
  Widget _bottomBar(bool isLast) {
    final saveLabel = widget.setup ? 'Submit for review' : 'Save';
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.md),
          child: Row(
            children: [
              if (_step > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _goTo(_step - 1),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: Gaps.md),
              ],
              if (!widget.setup && !isLast) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _next,
                    child: const Text('Next'),
                  ),
                ),
                const SizedBox(width: Gaps.md),
              ],
              Expanded(
                flex: 2,
                child: widget.setup && !isLast
                    ? FilledButton(onPressed: _next, child: const Text('Next'))
                    : LoadingButton(label: saveLabel, loading: _saving, onPressed: _save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStep {
  const _ProfileStep(this.title, this.fields);

  final String title;
  final List<Widget> fields;
}

/// "Step 2 of 4", a progress bar and the step names; tapping a name opens that step.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.steps, required this.current, required this.onTap});

  final List<_ProfileStep> steps;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, Gaps.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${current + 1} of ${steps.length}',
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: Gaps.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: LinearProgressIndicator(
              value: (current + 1) / steps.length,
              minHeight: 6,
              backgroundColor: colors.primary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: Gaps.xs),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
                      child: Text(
                        steps[i].title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: i == current ? colors.primary : colors.onSurfaceVariant,
                          fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
