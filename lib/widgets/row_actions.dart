import 'package:flutter/material.dart';

import 'confirm_dialog.dart';

List<Widget> buildRowActions(
  BuildContext context, {
  required String name,
  VoidCallback? onEdit,
  Future<String?> Function()? onDelete,
  List<Widget> extra = const [],
}) {
  Future<void> report(Future<String?> Function() action) async {
    final problem = await action();
    if (problem == null || !context.mounted) return;
    await showNotice(context, title: 'Действие невозможно', message: problem);
  }

  return [
    ...extra,
    if (onEdit != null)
      IconButton(tooltip: 'Изменить', icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
    if (onDelete != null)
      IconButton(
        tooltip: 'Удалить',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final confirmed = await confirmAction(
            context,
            title: 'Удалить запись?',
            message: '«$name» будет удалена без возможности восстановления.',
          );
          if (confirmed) await report(onDelete);
        },
      ),
  ];
}
