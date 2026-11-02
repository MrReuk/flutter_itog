import 'package:flutter/material.dart';

import '../core/breakpoints.dart';
import 'debounced_text_field.dart';

const double kToolbarFullWidth = 680;

class ListToolbar extends StatefulWidget {
  const ListToolbar({
    super.key,
    required this.search,
    required this.searchLabel,
    required this.onSearch,
    required this.filters,
    required this.activeFilterCount,
    required this.onReset,
    this.initiallyOpen = false,
    this.onAdd,
    this.addLabel = 'Добавить',
    this.showSearch = true,
  });

  final String search;
  final String searchLabel;
  final ValueChanged<String> onSearch;
  final List<Widget> filters;
  final int activeFilterCount;
  final VoidCallback onReset;
  final bool initiallyOpen;
  final VoidCallback? onAdd;
  final String addLabel;
  final bool showSearch;

  @override
  State<ListToolbar> createState() => _ListToolbarState();
}

class _ListToolbarState extends State<ListToolbar> {
  bool _open = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _open = widget.initiallyOpen || screenSizeOf(context) == ScreenSize.expanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.activeFilterCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow =
              screenSizeOf(context) == ScreenSize.compact ||
              constraints.maxWidth < kToolbarFullWidth;
          return _buildColumn(context, count, narrow);
        },
      ),
    );
  }

  Widget _buildColumn(BuildContext context, int count, bool narrow) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.showSearch) ...[
              Expanded(
                child: DebouncedTextField(
                  value: widget.search,
                  onChanged: widget.onSearch,
                  decoration: InputDecoration(
                    labelText: widget.searchLabel,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else
              const Spacer(),
            if (narrow)
              IconButton.outlined(
                tooltip: count > 0 ? 'Фильтры ($count)' : 'Фильтры',
                onPressed: () => setState(() => _open = !_open),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: Icon(_open ? Icons.expand_less : Icons.tune),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => setState(() => _open = !_open),
                icon: Icon(_open ? Icons.expand_less : Icons.tune),
                label: Text(count > 0 ? 'Фильтры ($count)' : 'Фильтры'),
              ),
            if (widget.onAdd != null) ...[
              const SizedBox(width: 8),
              if (narrow)
                IconButton.filled(
                  tooltip: widget.addLabel,
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                )
              else
                FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(widget.addLabel),
                ),
            ],
          ],
        ),
        if (_open) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...widget.filters,
                  TextButton.icon(
                    onPressed: widget.onReset,
                    icon: const Icon(Icons.clear),
                    label: const Text('Сбросить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
