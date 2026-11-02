import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final double hideBelow;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
    this.hideBelow = 0,
  });
}

class CellText extends StatelessWidget {
  const CellText(this.text, {super.key, this.maxWidth = 260});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<bool>? onSelectAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;
  final void Function(T item)? onOpen;
  final bool Function(T item)? isDeleted;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.onOpen,
    this.isDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final toggle = onToggleSelect;
    final selectAll = onSelectAll;
    final sort = onSort;
    final open = onOpen;
    final rowActions = actions;
    final deletedOf = isDeleted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final visible = columns.where((c) => constraints.maxWidth >= c.hideBelow).toList();
        final sortIndex = visible.indexWhere((c) => c.sortField == sortField);
        final activeIndex = sortField == null || sortIndex < 0 ? null : sortIndex;

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 16,
                showCheckboxColumn: toggle != null,
                sortColumnIndex: activeIndex,
                sortAscending: sortAscending,
                onSelectAll: selectAll == null ? null : (value) => selectAll(value ?? false),
                columns: [
                  for (final column in visible)
                    DataColumn(
                      label: Text(column.label),
                      numeric: column.numeric,
                      onSort: column.sortField == null || sort == null
                          ? null
                          : (index, ascending) => sort(column.sortField!),
                    ),
                  if (rowActions != null) const DataColumn(label: Text('Действия')),
                ],
                rows: [
                  for (final item in items)
                    _buildRow(item, visible, toggle, open, rowActions, deletedOf),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildRow(
    T item,
    List<TableColumnSpec<T>> visible,
    ValueChanged<String>? toggle,
    void Function(T item)? open,
    List<Widget> Function(T item)? rowActions,
    bool Function(T item)? deletedOf,
  ) {
    final id = idOf(item);
    final deleted = deletedOf != null && deletedOf(item);
    return DataRow(
      key: ValueKey(id),
      selected: selected.contains(id),
      onSelectChanged: toggle == null ? null : (_) => toggle(id),
      cells: [
        for (final column in visible)
          DataCell(
            Opacity(
              opacity: deleted ? 0.5 : 1,
              child: DefaultTextStyle.merge(
                style: TextStyle(decoration: deleted ? TextDecoration.lineThrough : null),
                child: column.build(item),
              ),
            ),
            onTap: open == null ? null : () => open(item),
          ),
        if (rowActions != null)
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: rowActions(item))),
      ],
    );
  }
}
