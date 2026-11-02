import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../repositories/repository_exception.dart';
import '../state/paged_list_notifier.dart';
import '../state/reference_notifier.dart';
import '../state/unsaved_changes.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/entity_form.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/state_views.dart';

class EntityFormScreen<T> extends StatefulWidget {
  const EntityFormScreen({
    super.key,
    required this.title,
    required this.backPath,
    required this.notFoundMessage,
    required this.savedMessage,
    required this.loadItem,
    required this.fields,
    required this.initialValues,
    required this.save,
    this.needsRefs = false,
  });

  final String title;
  final String backPath;
  final String notFoundMessage;
  final String savedMessage;
  final Future<T?> Function()? loadItem;
  final List<FieldSpec> Function(T? item) fields;
  final FormValues Function(T? item) initialValues;
  final Future<void> Function(FormValues values, T? existing) save;
  final bool needsRefs;

  @override
  State<EntityFormScreen<T>> createState() => _EntityFormScreenState<T>();
}

class _EntityFormScreenState<T> extends State<EntityFormScreen<T>> {
  final UnsavedChanges _unsaved = UnsavedChanges();
  late Future<T?> _loading;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loading = _prepare();
  }

  Future<T?> _prepare() async {
    if (widget.needsRefs) {
      final refs = context.read<ReferenceNotifier>();
      await refs.load();
      if (refs.failed) {
        throw RepositoryException(refs.error ?? 'Справочники не загружены');
      }
    }
    final loader = widget.loadItem;
    return loader == null ? null : await loader();
  }

  void _leave(bool changed) {
    if (context.canPop()) {
      context.pop(changed);
    } else {
      context.go(widget.backPath);
    }
  }

  void _refreshList() {
    try {
      context.read<PagedListNotifier<T>>().load();
    } catch (_) {}
  }

  void _leaveClean(bool changed) {
    _unsaved.dirty = false;
    setState(() => _dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leave(changed);
    });
  }

  Future<Map<String, String>> _submit(FormValues values, T? existing) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.save(values, existing);
    } on ValidationException catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сервер отклонил данные. Проверьте выделенные поля.')),
      );
      return e.errors;
    } on ConflictException catch (e) {
      if (e.errors.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return e.errors;
      }
      if (mounted) {
        await showNotice(context, title: 'Действие невозможно', message: e.message);
      }
      return const {};
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось сохранить: ${describeError(e)}')));
      return const {};
    }
    messenger.showSnackBar(SnackBar(content: Text(widget.savedMessage)));
    if (mounted) {
      _refreshList();
      _leaveClean(true);
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await confirmDiscard(context);
        if (leave && mounted) _leaveClean(false);
      },
      child: AppScaffold(
        title: widget.title,
        showBack: true,
        backPath: widget.backPath,
        unsaved: _unsaved,
        body: FutureBuilder<T?>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(
                message: 'Не удалось открыть форму: ${describeError(snapshot.error!)}',
                onRetry: () => setState(() {
                  _loading = _prepare();
                }),
              );
            }
            final item = snapshot.data;
            if (widget.loadItem != null && item == null) {
              return EmptyView(
                message: widget.notFoundMessage,
                actionLabel: 'К списку',
                onAction: () => context.go(widget.backPath),
              );
            }
            return EntityForm(
              fields: widget.fields(item),
              initialValues: widget.initialValues(item),
              onSubmit: (values) => _submit(values, item),
              onDirtyChanged: (dirty) {
                _unsaved.dirty = dirty;
                setState(() => _dirty = dirty);
              },
              onCancel: () => guardedNavigate(context, _unsaved, () => _leaveClean(false)),
            );
          },
        ),
      ),
    );
  }
}
