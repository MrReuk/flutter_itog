import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../state/paged_list_notifier.dart';
import '../state/reference_notifier.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/entity_list_body.dart';
import '../widgets/entity_table.dart';
import '../widgets/list_toolbar.dart';
import '../widgets/row_actions.dart';
import '../widgets/selection_bar.dart';

typedef FiltersBuilder =
    List<Widget> Function(
      BuildContext context,
      ListQuery query,
      void Function(ListQuery next) apply,
    );

class EntityListScreen<T> extends StatefulWidget {
  const EntityListScreen({
    super.key,
    required this.title,
    required this.path,
    required this.query,
    required this.searchLabel,
    required this.emptyMessage,
    required this.columns,
    required this.idOf,
    required this.titleOf,
    required this.subtitleOf,
    this.filters,
    this.canManage = false,
    this.addLabel = 'Добавить',
    this.newPath,
    this.editPath,
    this.openPath,
    this.deleteName,
    this.extraActions,
    this.reloadReferences = false,
    this.showSearch = true,
    this.header,
    this.canDelete,
    this.selectable = true,
  });

  final String title;

  final String path;
  final ListQuery query;
  final String searchLabel;
  final String emptyMessage;
  final List<TableColumnSpec<T>> columns;
  final String Function(T item) idOf;
  final String Function(T item) titleOf;
  final String Function(T item) subtitleOf;
  final FiltersBuilder? filters;

  final bool canManage;
  final String addLabel;
  final String? newPath;
  final String Function(T item)? editPath;
  final String Function(T item)? openPath;
  final String Function(T item)? deleteName;
  final List<Widget> Function(BuildContext context, T item)? extraActions;

  final bool reloadReferences;
  final bool showSearch;
  final Widget? header;

  final bool Function(T item)? canDelete;

  final bool selectable;

  @override
  State<EntityListScreen<T>> createState() => _EntityListScreenState<T>();
}

class _EntityListScreenState<T> extends State<EntityListScreen<T>> {
  PagedListNotifier<T> get _notifier => context.read<PagedListNotifier<T>>();

  void _go(ListQuery next) => context.go(next.toLocation(widget.path));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.applyQuery(widget.query, force: true);
    });
  }

  @override
  void didUpdateWidget(EntityListScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifier.applyQuery(widget.query);
      });
    }
  }

  void _reloadRefs() {
    if (widget.reloadReferences && mounted) {
      context.read<ReferenceNotifier>().load();
    }
  }

  Future<void> _open(String location) async {
    final changed = await context.push<bool>(location);
    if (changed != true || !mounted) return;
    await _notifier.load();
    _reloadRefs();
  }

  Future<String?> _afterChange(Future<String?> Function() operation) async {
    final problem = await operation();
    if (problem == null) _reloadRefs();
    return problem;
  }

  Future<void> _deleteSelected() async {
    final notifier = _notifier;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить выбранные записи?',
      message: 'Будет удалено записей: ${notifier.selected.length}. Это действие необратимо.',
    );
    if (!confirmed) return;
    final summary = await notifier.deleteSelected();
    _reloadRefs();
    final failure = summary.error;
    final text = failure != null
        ? 'Не удалось удалить записи: $failure'
        : summary.deleted < summary.requested
        ? 'Удалено записей: ${summary.deleted} из ${summary.requested}. '
              'Остальные используются в других данных.'
        : 'Удалено записей: ${summary.deleted}';
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<PagedListNotifier<T>>();
    final q = widget.query;
    final canManage = widget.canManage;
    final open = widget.openPath;
    final edit = widget.editPath;
    final nameOf = widget.deleteName ?? widget.titleOf;

    return AppScaffold(
      title: widget.title,
      body: Column(
        children: [
          ?widget.header,
          ListToolbar(
            search: q.search,
            searchLabel: widget.searchLabel,
            showSearch: widget.showSearch,
            onSearch: (text) => _go(q.copyWith(search: text)),
            activeFilterCount: q.activeFilterCount,
            initiallyOpen: q.activeFilterCount > 0,
            onReset: () => _go(q.reset()),
            addLabel: widget.addLabel,
            onAdd: canManage && widget.newPath != null ? () => _open(widget.newPath!) : null,
            filters: widget.filters?.call(context, q, _go) ?? const [],
          ),
          if (notifier.hasSelection)
            SelectionBar(
              count: notifier.selected.length,
              onDelete: _deleteSelected,
              onClear: notifier.clearSelection,
            ),
          Expanded(
            child: EntityListBody<T>(
              status: notifier.status,
              error: notifier.error,
              result: notifier.result,
              onRetry: notifier.load,
              offline: notifier.offline,
              emptyMessage: widget.emptyMessage,
              onReset: q.search.isNotEmpty || q.activeFilterCount > 0 ? () => _go(q.reset()) : null,
              columns: widget.columns,
              idOf: widget.idOf,
              selected: notifier.selected,
              onToggleSelect: canManage && widget.selectable ? notifier.toggleSelection : null,
              onSelectAll: canManage && widget.selectable ? notifier.setAllSelected : null,
              sortField: q.sortField,
              sortAscending: q.sortAscending,
              onSort: (field) => _go(
                q.copyWith(
                  sortField: field,
                  sortAscending: field == q.sortField ? !q.sortAscending : true,
                ),
              ),
              onOpen: open == null ? null : (item) => _open(open(item)),
              actions: (item) => buildRowActions(
                context,
                name: nameOf(item),
                extra: widget.extraActions?.call(context, item) ?? const [],
                onEdit: canManage && edit != null ? () => _open(edit(item)) : null,
                onDelete: canManage && (widget.canDelete?.call(item) ?? true)
                    ? () => _afterChange(() => notifier.delete(widget.idOf(item)))
                    : null,
              ),
              titleOf: widget.titleOf,
              subtitleOf: widget.subtitleOf,
              onPage: (page) => _go(q.copyWith(page: page)),
              onSize: (size) => _go(q.copyWith(size: size)),
            ),
          ),
        ],
      ),
    );
  }
}
