import 'package:flutter/material.dart';

import '../models/named_option.dart';

class IdDropdown extends StatelessWidget {
  const IdDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 220,
  });

  final String label;
  final String? value;
  final List<NamedOption> options;
  final ValueChanged<String?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    final current = options.any((o) => o.id == value) ? value : null;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$label-$current-${options.length}'),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Все')),
          for (final option in options)
            DropdownMenuItem<String?>(value: option.id, child: Text(option.name)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
