import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:atrium_cinema/models/genre.dart';
import 'package:atrium_cinema/models/list_query.dart';
import 'package:atrium_cinema/models/list_specs.dart';
import 'package:atrium_cinema/models/page_result.dart';
import 'package:atrium_cinema/state/load_status.dart';
import 'package:atrium_cinema/state/paged_list_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late MemoryRepo<Genre> repo;
  late PagedListNotifier<Genre> notifier;

  setUp(() {
    repo = genreRepo([
      for (var i = 1; i <= 25; i++) Genre(id: 'g$i', title: 'Жанр ${i.toString().padLeft(2, '0')}'),
    ]);
    notifier = PagedListNotifier<Genre>(
      initialQuery: ListQuery.initial(kGenreSpec),
      repository: repo,
      idOf: (g) => g.id,
    );
  });

  group('Загрузка списка', () {
    test('до загрузки список пуст и статус «ожидание»', () {
      expect(notifier.status, LoadStatus.idle);
      expect(notifier.result.items, isEmpty);
    });

    test('первая страница и общее число записей', () async {
      await notifier.load();

      expect(notifier.status, LoadStatus.success);
      expect(notifier.result.items, hasLength(10));
      expect(notifier.result.total, 25);
      expect(notifier.result.totalPages, 3);
      expect(notifier.error, isNull);
    });

    test('во время загрузки виден статус «загрузка»', () async {
      repo.delay = const Duration(milliseconds: 20);
      final statuses = <LoadStatus>[];
      notifier.addListener(() => statuses.add(notifier.status));

      await notifier.load();

      expect(statuses, [LoadStatus.loading, LoadStatus.success]);
    });

    test('пустой результат — успех с нулём записей, а не ошибка', () async {
      await notifier.applyQuery(notifier.query.copyWith(search: 'такого нет'));

      expect(notifier.status, LoadStatus.success);
      expect(notifier.result.total, 0);
      expect(notifier.result.items, isEmpty);
    });

    test('сбой сервера даёт статус «ошибка» с текстом, повтор исправляет', () async {
      repo.failNext = const ServerException();

      await notifier.load();

      expect(notifier.status, LoadStatus.error);
      expect(notifier.error, contains('Не удалось загрузить список'));
      expect(notifier.offline, isFalse);

      await notifier.load();

      expect(notifier.status, LoadStatus.success);
      expect(notifier.error, isNull);
    });

    test('недоступный сервер помечается отдельным признаком', () async {
      repo.failNext = const NetworkException();

      await notifier.load();

      expect(notifier.offline, isTrue);
    });

    test('устаревший ответ не затирает свежий', () async {
      repo.delay = const Duration(milliseconds: 40);
      final slow = notifier.load();
      repo.delay = Duration.zero;

      await notifier.applyQuery(notifier.query.copyWith(search: 'Жанр 2'));
      await slow;

      expect(notifier.result.total, 6);
      expect(notifier.query.search, 'Жанр 2');
    });
  });

  group('Условия отбора', () {
    test('запрос с теми же условиями не перезагружает список', () async {
      await notifier.load();
      final calls = repo.findCalls;

      await notifier.applyQuery(notifier.query);

      expect(repo.findCalls, calls);

      await notifier.applyQuery(notifier.query, force: true);

      expect(repo.findCalls, calls + 1);
    });

    test('смена страницы и сортировки доходит до хранилища', () async {
      await notifier.applyQuery(notifier.query.copyWith(page: 3));
      expect(repo.lastQuery?.page, 3);
      expect(notifier.result.items, hasLength(5));

      await notifier.applyQuery(notifier.query.copyWith(sortAscending: false, page: 1));
      expect(notifier.result.items.first.title, 'Жанр 25');
    });

    test('смена условий сбрасывает выделение', () async {
      await notifier.load();
      notifier.toggleSelection('g1');
      expect(notifier.hasSelection, isTrue);

      await notifier.applyQuery(notifier.query.copyWith(search: '1'));

      expect(notifier.hasSelection, isFalse);
    });
  });

  group('Выделение и удаление', () {
    test('выделение строк и «выделить все на странице»', () async {
      await notifier.load();

      notifier.toggleSelection('g1');
      notifier.toggleSelection('g2');
      notifier.toggleSelection('g1');
      expect(notifier.selected, {'g2'});

      notifier.setAllSelected(true);
      expect(notifier.selected, hasLength(10));

      notifier.setAllSelected(false);
      expect(notifier.hasSelection, isFalse);

      notifier.toggleSelection('g5');
      notifier.clearSelection();
      expect(notifier.selected, isEmpty);
    });

    test('удаление записи обновляет список', () async {
      await notifier.load();

      final error = await notifier.delete('g1');

      expect(error, isNull);
      expect(notifier.result.total, 24);
    });

    test('запись со связями не удаляется, причина возвращается текстом', () async {
      await notifier.load();
      repo.protectedIds.add('g1');

      final error = await notifier.delete('g1');

      expect(error, contains('используется'));
      expect(notifier.result.total, 25);
    });

    test('групповое удаление сообщает, сколько записей удалено', () async {
      await notifier.load();
      repo.protectedIds.add('g2');
      notifier.toggleSelection('g1');
      notifier.toggleSelection('g2');
      notifier.toggleSelection('g3');

      final summary = await notifier.deleteSelected();

      expect(summary.requested, 3);
      expect(summary.deleted, 2);
      expect(summary.error, isNull);
      expect(notifier.result.total, 23);
      expect(notifier.hasSelection, isFalse);
    });
  });

  test('после удаления страницы уведомления не приходят', () async {
    var count = 0;
    notifier.addListener(() => count++);
    await notifier.load();
    final before = count;

    notifier.dispose();
    notifier.toggleSelection('g1');

    expect(count, before);
  });

  group('Страница результата', () {
    test('срез списка и границы страниц', () {
      final rows = List.generate(25, (i) => i);

      final last = PageResult<int>.slice(rows, page: 3, size: 10);
      expect(last.items, [20, 21, 22, 23, 24]);
      expect(last.hasNext, isFalse);
      expect(last.hasPrevious, isTrue);

      final beyond = PageResult<int>.slice(rows, page: 99, size: 10);
      expect(beyond.page, 3);

      final empty = PageResult<int>.slice(const [], page: 1, size: 10);
      expect(empty.totalPages, 1);
      expect(empty.items, isEmpty);
    });
  });
}
