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

/// Short text tags as removable chips plus an input to add more — owner skills, listing tech stack.
class TagsField extends FormField<List<String>> {
  TagsField({
    super.key,
    required List<String> initial,
    required ValueChanged<List<String>> onChanged,
    required String label,
    required String hint,
    required IconData icon,
    String? emptyError, // null = tags are optional
    required int maxCount,
    required String maxError,
    int maxLength = 40,
    String? serverError,
  }) : super(
         initialValue: initial,
         forceErrorText: serverError,
         validator: (tags) {
           if ((tags == null || tags.isEmpty) && emptyError != null) return emptyError;
           if ((tags?.length ?? 0) > maxCount) return maxError;
           return null;
         },
         builder: (state) =>
             _TagsInput(state: state, onChanged: onChanged, label: label, hint: hint, icon: icon, maxLength: maxLength),
       );
}

class _TagsInput extends StatefulWidget {
  const _TagsInput({
    required this.state,
    required this.onChanged,
    required this.label,
    required this.hint,
    required this.icon,
    required this.maxLength,
  });

  final FormFieldState<List<String>> state;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLength;

  @override
  State<_TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<_TagsInput> {
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
    if (skill.isEmpty || skill.length > widget.maxLength) return;
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
          maxLength: widget.maxLength,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
            counterText: '',
            errorText: widget.state.errorText,
            suffixIcon: IconButton(tooltip: 'Add', icon: const Icon(Icons.add), onPressed: _add),
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
