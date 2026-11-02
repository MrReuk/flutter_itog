import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/json_helpers.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import 'entity_repository.dart';

const int kReferencePageSize = 200;
const Duration kCacheLifetime = Duration(minutes: 5);

String pbQuote(String value) {
  final cleaned = value.replaceAll('\\', '').replaceAll("'", "\\'");
  return "'$cleaned'";
}

class FilterBuilder {
  final List<String> _parts = [];

  void add(String expression) => _parts.add('($expression)');

  void addIf(String value, String Function(String quoted) expression) {
    final text = value.trim();
    if (text.isNotEmpty) add(expression(pbQuote(text)));
  }

  String build() => _parts.join(' && ');
}

abstract class PbRepository<T> implements EntityRepository<T>, CachedRepository {
  PbRepository({
    required this.dio,
    required this.collection,
    this.expand = '',
    this.cacheAll = false,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Dio dio;
  final String collection;

  final String expand;
  final bool cacheAll;
  final DateTime Function() _now;

  DateTime Function() get clock => _now;

  CancelToken? _findToken;
  Future<List<T>>? _cache;
  DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);

  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toBody(T item);
  String idOf(T item);

  String filterOf(ListQuery query);

  String sortFieldOf(String field) => field;

  String get path => '/collections/$collection/records';

  Map<String, dynamic> queryOf(ListQuery query) {
    final filter = filterOf(query);
    final sort = sortFieldOf(query.sortField);
    return {
      'page': query.page,
      'perPage': query.size,
      'sort': query.sortAscending ? sort : '-$sort',
      if (filter.isNotEmpty) 'filter': filter,
      if (expand.isNotEmpty) 'expand': expand,
    };
  }

  PageResult<T> parsePage(Object? data) {
    final map = jsonMap(data);
    final raw = map['items'];
    if (raw is! List) {
      throw const FormatException('В ответе нет списка items');
    }
    return PageResult<T>(
      items: [for (final element in raw) fromJson(jsonMap(element))],
      page: jsonInt(map['page'], 1),
      size: jsonInt(map['perPage'], kDefaultPageSize),
      total: jsonInt(map['totalItems']),
    );
  }

  @override
  void invalidate() {
    _cache = null;
  }

  @override
  Future<PageResult<T>> find(ListQuery query) {
    _findToken?.cancel('Запрос устарел');
    final token = _findToken = CancelToken();
    return guard(() async {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: queryOf(query),
        cancelToken: token,
      );
      return parsePage(response.data);
    });
  }

  @override
  Future<List<T>> findAll() async {
    if (!cacheAll) return _loadAll();

    final fresh = _cache != null && _now().difference(_cachedAt) < kCacheLifetime;
    if (!fresh) {
      _cache = _loadAll();
      _cachedAt = _now();
    }
    final pending = _cache!;
    try {
      return await pending;
    } catch (_) {
      if (identical(_cache, pending)) _cache = null;
      rethrow;
    }
  }

  String get defaultSort => 'id';

  Future<List<T>> _loadAll() {
    return guard(() async {
      final items = <T>[];
      var page = 1;
      while (true) {
        final response = await dio.get<dynamic>(
          path,
          queryParameters: {
            'page': page,
            'perPage': kReferencePageSize,
            'sort': defaultSort,
            if (expand.isNotEmpty) 'expand': expand,
          },
        );
        final chunk = parsePage(response.data);
        items.addAll(chunk.items);
        if (chunk.items.isEmpty || page >= chunk.totalPages) break;
        page++;
      }
      return List<T>.unmodifiable(items);
    });
  }

  @override
  Future<T?> findById(String id) async {
    try {
      return await guard<T?>(() async {
        final response = await dio.get<dynamic>(
          '$path/$id',
          queryParameters: {if (expand.isNotEmpty) 'expand': expand},
        );
        return fromJson(jsonMap(response.data));
      });
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<T> create(T item) {
    return guard(() async {
      try {
        final response = await dio.post<dynamic>(
          path,
          data: toBody(item),
          queryParameters: {if (expand.isNotEmpty) 'expand': expand},
        );
        return fromJson(jsonMap(response.data));
      } finally {
        invalidate();
      }
    });
  }

  @override
  Future<T> update(T item) {
    return guard(() async {
      try {
        final response = await dio.patch<dynamic>(
          '$path/${idOf(item)}',
          data: toBody(item),
          queryParameters: {if (expand.isNotEmpty) 'expand': expand},
        );
        return fromJson(jsonMap(response.data));
      } finally {
        invalidate();
      }
    });
  }

  @override
  Future<void> delete(String id) {
    return guard(() async {
      try {
        await dio.delete<dynamic>('$path/$id');
      } on DioException catch (e) {
        throw _deleteError(mapDioError(e));
      } finally {
        invalidate();
      }
    });
  }

  ApiException _deleteError(ApiException error) {
    if (error is ForbiddenException && error.message.contains('delete')) {
      return const ConflictException(
        'Запись используется в других данных (например, у зала есть сеансы или фильм назначен на сеанс). '
        'Сначала удалите или измените связанные записи.',
      );
    }
    return error;
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var deleted = 0;
    Object? firstError;
    for (final id in ids) {
      try {
        await delete(id);
        deleted++;
      } on ApiException catch (e) {
        if (e is NetworkException || e is UnauthorizedException) rethrow;
        firstError ??= e;
      }
    }
    if (deleted == 0 && firstError != null) throw firstError;
    return deleted;
  }
}
