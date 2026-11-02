import 'package:flutter/material.dart';

import '../state/unsaved_changes.dart';

const double kDialogMaxWidth = 440;

Widget _dialogText(String message) {
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: kDialogMaxWidth),
    child: Text(message),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Удалить',
  String cancelLabel = 'Отмена',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: _dialogText(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showNotice(BuildContext context, {required String title, required String message}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.block, color: Theme.of(dialogContext).colorScheme.error),
      title: Text(title),
      content: _dialogText(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDiscard(BuildContext context) {
  return confirmAction(
    context,
    title: 'Выйти без сохранения?',
    message: 'Изменения в форме не сохранены и будут потеряны.',
    confirmLabel: 'Выйти',
    cancelLabel: 'Остаться',
  );
}

Future<void> guardedNavigate(
  BuildContext context,
  UnsavedChanges? guard,
  VoidCallback navigate,
) async {
  if (guard == null || !guard.dirty) {
    navigate();
    return;
  }
  final discard = await confirmDiscard(context);
  if (discard && context.mounted) navigate();
}
