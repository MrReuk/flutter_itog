import 'page_result.dart';

class ListSpec {
  const ListSpec({
    required this.sortFields,
    required this.defaultSort,
    this.defaultAscending = true,
    this.filterKeys = const [],
    this.filterDefaults = const {},
  });

  final List<String> sortFields;
  final String defaultSort;
  final bool defaultAscending;

  final List<String> filterKeys;

  final Map<String, String> filterDefaults;
}

int _parseInt(String? raw, int fallback) => int.tryParse(raw ?? '') ?? fallback;

class ListQuery {
  const ListQuery({
    required this.spec,
    this.search = '',
    this.filters = const {},
    String? sortField,
    bool? sortAscending,
    this.page = 1,
    this.size = kDefaultPageSize,
  }) : _sortField = sortField,
       _sortAscending = sortAscending;

  final ListSpec spec;
  final String search;

  final Map<String, String> filters;
  final String? _sortField;
  final bool? _sortAscending;
  final int page;
  final int size;

  String get sortField => _sortField ?? spec.defaultSort;
  bool get sortAscending => _sortAscending ?? spec.defaultAscending;

  String filter(String key) => filters[key] ?? '';

  factory ListQuery.initial(ListSpec spec) => ListQuery.fromParams(spec, const {});

  factory ListQuery.fromParams(ListSpec spec, Map<String, String> params) {
    final sortRaw = (params['sort'] ?? '').split(',');
    final known = spec.sortFields.contains(sortRaw.first);
    final field = known ? sortRaw.first : spec.defaultSort;
    final ascending = !known
        ? spec.defaultAscending
        : sortRaw.length > 1
        ? sortRaw[1] != 'desc'
        : (field == spec.defaultSort ? spec.defaultAscending : true);
    final size = _parseInt(params['size'], kDefaultPageSize);
    final page = _parseInt(params['page'], 1);
    return ListQuery(
      spec: spec,
      search: params['search'] ?? '',
      filters: {
        for (final key in spec.filterKeys)
          if ((params[key] ?? spec.filterDefaults[key] ?? '').isNotEmpty)
            key: params[key] ?? spec.filterDefaults[key]!,
      },
      sortField: field,
      sortAscending: ascending,
      page: page < 1 ? 1 : page,
      size: kPageSizes.contains(size) ? size : kDefaultPageSize,
    );
  }

  int get activeFilterCount {
    return filters.entries.where((e) => spec.filterDefaults[e.key] != e.value).length;
  }

  Map<String, String> toParams() {
    return {
      if (search.isNotEmpty) 'search': search,
      for (final entry in filters.entries)
        if (spec.filterDefaults[entry.key] != entry.value) entry.key: entry.value,
      if (sortField != spec.defaultSort || sortAscending != spec.defaultAscending)
        'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
      if (page > 1) 'page': '$page',
      if (size != kDefaultPageSize) 'size': '$size',
    };
  }

  String toLocation(String path) {
    final params = toParams();
    return Uri(path: path, queryParameters: params.isEmpty ? null : params).toString();
  }

  ListQuery copyWith({
    String? search,
    Map<String, String>? filters,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
  }) {
    return ListQuery(
      spec: spec,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
    );
  }

  ListQuery withFilter(String key, String value) {
    final next = Map<String, String>.of(filters);
    final fallback = spec.filterDefaults[key] ?? '';
    final effective = value.isEmpty ? fallback : value;
    if (effective.isEmpty) {
      next.remove(key);
    } else {
      next[key] = effective;
    }
    return copyWith(filters: next);
  }

  ListQuery reset() {
    return ListQuery(
      spec: spec,
      filters: Map<String, String>.of(spec.filterDefaults),
      sortField: sortField,
      sortAscending: sortAscending,
      size: size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListQuery &&
          other.spec == spec &&
          other.search == search &&
          _mapEquals(other.filters, filters) &&
          other.sortField == sortField &&
          other.sortAscending == sortAscending &&
          other.page == page &&
          other.size == size;

  @override
  int get hashCode => Object.hash(
    spec,
    search,
    Object.hashAllUnordered(filters.entries.map((e) => Object.hash(e.key, e.value))),
    sortField,
    sortAscending,
    page,
    size,
  );
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
