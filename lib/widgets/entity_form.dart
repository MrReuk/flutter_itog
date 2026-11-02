import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/named_option.dart';
import '../validation/validators.dart';

typedef FormValues = Map<String, Object?>;
typedef OptionsBuilder = List<NamedOption> Function(FormValues values);
typedef SubmitHandler = Future<Map<String, String>> Function(FormValues values);

enum FieldKind { text, dropdown, multi, group }

class FieldSpec {
  const FieldSpec._({
    required this.kind,
    required this.key,
    required this.label,
    this.required = false,
    this.textValidator,
    this.idValidator,
    this.idsValidator,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.formatters,
    this.hint,
    this.isDate = false,
    this.isDateTime = false,
    this.obscure = false,
    this.options,
    this.narrowed,
    this.narrowedSwitchLabel,
    this.narrowedHint,
    this.children = const [],
  });

  factory FieldSpec.text({
    required String key,
    required String label,
    TextValidator? validator,
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
    bool isDate = false,
    bool isDateTime = false,
    bool obscure = false,
  }) {
    return FieldSpec._(
      kind: FieldKind.text,
      key: key,
      label: label,
      required: required,
      textValidator: validator,
      hint: hint,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      formatters: formatters,
      isDate: isDate,
      isDateTime: isDateTime,
      obscure: obscure,
    );
  }

  factory FieldSpec.dropdown({
    required String key,
    required String label,
    required OptionsBuilder options,
    IdValidator? validator,
    bool required = false,
  }) {
    return FieldSpec._(
      kind: FieldKind.dropdown,
      key: key,
      label: label,
      required: required,
      idValidator: validator,
      options: options,
    );
  }

  factory FieldSpec.multi({
    required String key,
    required String label,
    required OptionsBuilder options,
    OptionsBuilder? narrowed,
    String? narrowedSwitchLabel,
    String? narrowedHint,
    IdsValidator? validator,
    bool required = false,
  }) {
    return FieldSpec._(
      kind: FieldKind.multi,
      key: key,
      label: label,
      required: required,
      idsValidator: validator,
      options: options,
      narrowed: narrowed,
      narrowedSwitchLabel: narrowedSwitchLabel,
      narrowedHint: narrowedHint,
    );
  }

  factory FieldSpec.group({required String title, required List<FieldSpec> fields}) {
    return FieldSpec._(kind: FieldKind.group, key: title, label: title, children: fields);
  }

  final FieldKind kind;
  final String key;
  final String label;
  final bool required;
  final TextValidator? textValidator;
  final IdValidator? idValidator;
  final IdsValidator? idsValidator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? formatters;
  final String? hint;
  final bool isDate;
  final bool isDateTime;
  final bool obscure;
  final OptionsBuilder? options;
  final OptionsBuilder? narrowed;
  final String? narrowedSwitchLabel;
  final String? narrowedHint;
  final List<FieldSpec> children;

  String get title => required ? '$label *' : label;
}

class EntityForm extends StatefulWidget {
  const EntityForm({
    super.key,
    required this.fields,
    required this.initialValues,
    required this.onSubmit,
    required this.onDirtyChanged,
    required this.onCancel,
    this.submitLabel = 'Сохранить',
  });

  final List<FieldSpec> fields;
  final FormValues initialValues;
  final SubmitHandler onSubmit;
  final ValueChanged<bool> onDirtyChanged;
  final VoidCallback onCancel;
  final String submitLabel;

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _ids = {};
  final Map<String, List<String>> _lists = {};
  final Map<String, bool> _showAll = {};
  final Map<String, ({String text, String message})> _serverErrors = {};
  late final FormValues _initial;
  bool _dirty = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final spec in _flatten(widget.fields)) {
      final initial = widget.initialValues[spec.key];
      switch (spec.kind) {
        case FieldKind.text:
          _controllers[spec.key] = TextEditingController(text: initial == null ? '' : '$initial');
        case FieldKind.dropdown:
          _ids[spec.key] = initial is String && initial.isNotEmpty ? initial : null;
        case FieldKind.multi:
          _lists[spec.key] = initial is List
              ? <String>[
                  for (final e in initial)
                    if (e is String) e,
                ]
              : <String>[];
        case FieldKind.group:
          break;
      }
    }
    _initial = _values();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Iterable<FieldSpec> _flatten(List<FieldSpec> fields) sync* {
    for (final field in fields) {
      if (field.kind == FieldKind.group) {
        yield* _flatten(field.children);
      } else {
        yield field;
      }
    }
  }

  FormValues _values() {
    return <String, Object?>{
      for (final entry in _controllers.entries) entry.key: entry.value.text,
      for (final entry in _ids.entries) entry.key: entry.value,
      for (final entry in _lists.entries) entry.key: List<String>.of(entry.value),
    };
  }

  bool _differs(FormValues a, FormValues b) {
    for (final key in a.keys) {
      final x = a[key];
      final y = b[key];
      if (x is List && y is List) {
        if (!listEquals(x, y)) return true;
      } else if (x != y) {
        return true;
      }
    }
    return false;
  }

  void _touch() {
    final dirty = _differs(_values(), _initial);
    if (dirty != _dirty) {
      _dirty = dirty;
      widget.onDirtyChanged(dirty);
    }
  }

  String? _validateText(FieldSpec spec, String? raw) {
    final value = raw ?? '';
    final server = _serverErrors[spec.key];
    if (server != null) {
      if (server.text == value) return server.message;
      _serverErrors.remove(spec.key);
    }
    return spec.textValidator?.call(value, _values());
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final values = _values();
    setState(() => _submitting = true);

    Map<String, String> errors;
    try {
      errors = await widget.onSubmit(values);
    } catch (e) {
      errors = const {};
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    if (errors.isNotEmpty) {
      _serverErrors.clear();
      errors.forEach((key, message) {
        _serverErrors[key] = (text: '${values[key] ?? ''}', message: message);
      });
      _formKey.currentState?.validate();
    }
  }

  Future<void> _pickDate(FieldSpec spec) async {
    final controller = _controllers[spec.key]!;
    final parsed = spec.isDateTime
        ? parseRuDateTime(controller.text)
        : parseRuDate(controller.text);
    final initial = parsed != null && parsed.year >= 2000 && parsed.year <= 2100
        ? parsed
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    if (!spec.isDateTime) {
      controller.text = formatRuDate(picked);
      _touch();
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !mounted) return;
    controller.text = formatRuDateTime(
      DateTime(picked.year, picked.month, picked.day, time.hour, time.minute),
    );
    _touch();
  }

  Widget _buildField(FieldSpec spec) {
    return switch (spec.kind) {
      FieldKind.text => _buildText(spec),
      FieldKind.dropdown => _buildDropdown(spec),
      FieldKind.multi => _buildMulti(spec),
      FieldKind.group => _buildGroup(spec),
    };
  }

  List<Widget> _buildFields(List<FieldSpec> fields) {
    return [
      for (final field in fields)
        Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildField(field)),
    ];
  }

  Widget _buildText(FieldSpec spec) {
    return TextFormField(
      controller: _controllers[spec.key],
      keyboardType: spec.keyboardType,
      inputFormatters: spec.formatters,
      obscureText: spec.obscure,
      minLines: spec.maxLines > 1 ? 3 : null,
      maxLines: spec.maxLines,
      maxLength: spec.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: spec.title,
        hintText: spec.hint,
        border: const OutlineInputBorder(),
        suffixIcon: spec.isDate || spec.isDateTime
            ? IconButton(
                tooltip: spec.isDateTime ? 'Выбрать дату и время' : 'Выбрать дату',
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _pickDate(spec),
              )
            : null,
      ),
      validator: (value) => _validateText(spec, value),
      onChanged: (_) => _touch(),
    );
  }

  Widget _buildDropdown(FieldSpec spec) {
    final options = spec.options!(_values());
    final current = _ids[spec.key];
    final value = options.any((o) => o.id == current) ? current : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${spec.key}-${options.length}'),
      initialValue: value,
      isExpanded: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      hint: const Text('Выберите значение'),
      decoration: InputDecoration(labelText: spec.title, border: const OutlineInputBorder()),
      items: [
        for (final option in options)
          DropdownMenuItem<String>(
            value: option.id,
            child: Text(option.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (picked) => spec.idValidator?.call(picked),
      onChanged: (picked) {
        setState(() => _ids[spec.key] = picked);
        _touch();
      },
    );
  }

  Widget _buildMulti(FieldSpec spec) {
    final values = _values();
    final selected = _lists[spec.key]!;
    final all = spec.options!(values);
    final narrowed = spec.narrowed?.call(values) ?? const <NamedOption>[];
    final canNarrow = narrowed.isNotEmpty;
    final showAll = _showAll[spec.key] ?? false;
    final useNarrow = canNarrow && !showAll;
    final shown = useNarrow
        ? [
            for (final option in all)
              if (narrowed.any((n) => n.id == option.id) || selected.contains(option.id)) option,
          ]
        : all;

    return FormField<List<String>>(
      initialValue: List<String>.of(selected),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (picked) => spec.idsValidator?.call(picked ?? const <String>[]),
      builder: (field) {
        final current = field.value ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                labelText: spec.title,
                errorText: field.errorText,
                border: const OutlineInputBorder(),
                helperText: useNarrow ? spec.narrowedHint : null,
                helperMaxLines: 2,
              ),
              child: shown.isEmpty
                  ? const Text('Нет доступных значений')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final option in shown)
                          FilterChip(
                            label: Text(option.name),
                            selected: current.contains(option.id),
                            onSelected: (on) {
                              final next = List<String>.of(field.value ?? const <String>[]);
                              if (on) {
                                next.add(option.id);
                              } else {
                                next.remove(option.id);
                              }
                              field.didChange(next);
                              setState(() => _lists[spec.key] = next);
                              _touch();
                            },
                          ),
                      ],
                    ),
            ),
            if (canNarrow)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(spec.narrowedSwitchLabel ?? 'Показать все варианты'),
                value: showAll,
                onChanged: (on) => setState(() => _showAll[spec.key] = on),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGroup(FieldSpec spec) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ..._buildFields(spec.children),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildFields(widget.fields),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _submitting ? null : widget.onCancel,
                      child: const Text('Отмена'),
                    ),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(widget.submitLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
