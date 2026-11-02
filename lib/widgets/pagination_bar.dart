import 'package:flutter/material.dart';

import '../models/page_result.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.result,
    required this.onPage,
    required this.onSize,
  });

  final PageResult<Object?> result;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  @override
  Widget build(BuildContext context) {
    final totalPages = result.totalPages;
    final sizeValue = kPageSizes.contains(result.size) ? result.size : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Всего записей: ${result.total}'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('На странице:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: sizeValue,
                    items: [
                      for (final size in kPageSizes)
                        DropdownMenuItem<int>(value: size, child: Text('$size')),
                    ],
                    onChanged: (value) {
                      if (value != null) onSize(value);
                    },
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Первая',
                icon: const Icon(Icons.first_page),
                onPressed: result.hasPrevious ? () => onPage(1) : null,
              ),
              IconButton(
                tooltip: 'Предыдущая',
                icon: const Icon(Icons.chevron_left),
                onPressed: result.hasPrevious ? () => onPage(result.page - 1) : null,
              ),
              Flexible(
                child: Text(
                  'Страница ${result.page} из $totalPages',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Следующая',
                icon: const Icon(Icons.chevron_right),
                onPressed: result.hasNext ? () => onPage(result.page + 1) : null,
              ),
              IconButton(
                tooltip: 'Последняя',
                icon: const Icon(Icons.last_page),
                onPressed: result.hasNext ? () => onPage(totalPages) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
