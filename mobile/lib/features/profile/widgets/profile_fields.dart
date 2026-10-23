import 'package:flutter/material.dart';

import '../data/profile_models.dart';

/// Section title inside the profile form.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Skills as removable chips plus an input to add more (1–20 skills).
class SkillsField extends FormField<List<String>> {
  SkillsField({super.key, required List<String> initial, required ValueChanged<List<String>> onChanged, String? serverError})
      : super(
          initialValue: initial,
          forceErrorText: serverError,
          validator: (skills) {
            if (skills == null || skills.isEmpty) return 'Add at least one skill';
            if (skills.length > 20) return 'Add at most 20 skills';
            return null;
          },
          builder: (state) => _SkillsInput(state: state, onChanged: onChanged),
        );
}

class _SkillsInput extends StatefulWidget {
  const _SkillsInput({required this.state, required this.onChanged});

  final FormFieldState<List<String>> state;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_SkillsInput> createState() => _SkillsInputState();
}

class _SkillsInputState extends State<_SkillsInput> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _set(List<String> skills) {
    widget.state.didChange(skills);
    widget.onChanged(skills);
  }

  void _add() {
    final skill = _input.text.trim();
    final skills = widget.state.value ?? [];
    if (skill.isEmpty || skill.length > 40) return;
    if (!skills.any((s) => s.toLowerCase() == skill.toLowerCase())) _set([...skills, skill]);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.state.value ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _input,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: 'Skills',
            hintText: 'e.g. Flutter, then press +',
            prefixIcon: const Icon(Icons.psychology_outlined),
            counterText: '',
            errorText: widget.state.errorText,
            suffixIcon: IconButton(tooltip: 'Add skill', icon: const Icon(Icons.add), onPressed: _add),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final skill in skills)
              InputChip(label: Text(skill), onDeleted: () => _set([...skills]..remove(skill))),
          ],
        ),
      ],
    );
  }
}

/// Category chips for investor and buyer interests (1–10).
class InterestsField extends FormField<Set<String>> {
  InterestsField({
    super.key,
    required List<Category> categories,
    required Set<String> initial,
    required ValueChanged<Set<String>> onChanged,
    String? serverError,
  }) : super(
          initialValue: initial,
          forceErrorText: serverError,
          validator: (ids) {
            if (ids == null || ids.isEmpty) return 'Choose at least one category';
            if (ids.length > 10) return 'Choose at most 10 categories';
            return null;
          },
          builder: (state) {
            final selected = state.value ?? {};
            final colors = Theme.of(state.context).colorScheme;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in categories)
                      FilterChip(
                        label: Text(c.name),
                        selected: selected.contains(c.id),
                        onSelected: (on) {
                          final next = {...selected};
                          on ? next.add(c.id) : next.remove(c.id);
                          state.didChange(next);
                          onChanged(next);
                        },
                      ),
                  ],
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(state.errorText!, style: TextStyle(color: colors.error, fontSize: 12)),
                  ),
              ],
            );
          },
        );
}
