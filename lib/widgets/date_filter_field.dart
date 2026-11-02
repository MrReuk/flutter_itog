import 'package:flutter/material.dart';

import '../models/format.dart';

class DateFilterField extends StatelessWidget {
  const DateFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 190,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final double width;

  Future<void> _pick(BuildContext context) async {
    final current = DateTime.tryParse(value);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    onChanged('${picked.year}-$month-$day');
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.tryParse(value);
    final text = day == null ? '' : formatCinemaDate(DateTime.utc(day.year, day.month, day.day));
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: day == null
                ? const Icon(Icons.calendar_today, size: 18)
                : IconButton(
                    tooltip: 'Сбросить дату',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onChanged(''),
                  ),
          ),
          child: Text(text.isEmpty ? 'Любая' : text),
        ),
      ),
    );
  }
}
