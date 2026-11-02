const List<int> kPageSizes = [10, 25, 50];
const int kDefaultPageSize = 10;

class PageResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;

  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  PageResult.empty() : items = <T>[], page = 1, size = kDefaultPageSize, total = 0;

  factory PageResult.slice(List<T> rows, {required int page, required int size}) {
    final total = rows.length;
    final pages = total == 0 ? 1 : (total + size - 1) ~/ size;
    final current = page < 1 ? 1 : (page > pages ? pages : page);
    final from = (current - 1) * size;
    final to = from + size > total ? total : from + size;
    return PageResult(items: rows.sublist(from, to), page: current, size: size, total: total);
  }

  int get totalPages => total == 0 ? 1 : (total / size).ceil();
  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;
}
