import '../models/list_query.dart';
import '../models/page_result.dart';

abstract interface class ListSource<T> {
  Future<PageResult<T>> find(ListQuery query);

  Future<void> delete(String id);

  Future<int> deleteMany(List<String> ids);
}

abstract interface class EntityRepository<T> implements ListSource<T> {
  Future<List<T>> findAll();

  Future<T?> findById(String id);
  Future<T> create(T item);
  Future<T> update(T item);
}

abstract interface class CachedRepository {
  void invalidate();
}
