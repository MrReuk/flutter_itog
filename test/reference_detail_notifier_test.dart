import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:atrium_cinema/models/genre.dart';
import 'package:atrium_cinema/repositories/repositories.dart';
import 'package:atrium_cinema/state/detail_notifier.dart';
import 'package:atrium_cinema/state/load_status.dart';
import 'package:atrium_cinema/state/reference_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

class _BrokenGenres implements GenreRepository {
  @override
  Future<List<Genre>> findAll() async => throw const NetworkException();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Справочники', () {
    late TestData data;

    ReferenceNotifier make({GenreRepository? genres}) {
      return ReferenceNotifier(
        genres: genres ?? genreRepo(data.genres),
        people: personRepo(data.people),
        halls: hallRepo(data.halls),
        movies: movieRepo(data.movies),
      );
    }

    setUp(() => data = TestData());

    test('до загрузки данных нет', () {
      final refs = make();

      expect(refs.ready, isFalse);
      expect(refs.halls, isEmpty);
    });

    test('после загрузки готовы все четыре справочника', () async {
      final refs = make();

      await refs.load();

      expect(refs.ready, isTrue);
      expect(refs.failed, isFalse);
      expect(refs.halls, hasLength(2));
      expect(refs.movies, hasLength(3));
    });

    test('варианты для выпадающих списков отсортированы и подписаны', () async {
      final refs = make();
      await refs.load();

      expect(refs.genreOptions().map((o) => o.name), ['Драма', 'Комедия', 'Триллер']);
      expect(refs.hallOptions().map((o) => o.name), ['Зал 1 (2D)', 'Зал VIP (VIP)']);
      expect(refs.movieOptions().map((o) => o.name), [
        'Лето в коммуналке (2023)',
        'Последний рейс (2025)',
        'Тихая гавань (2024)',
      ]);
      expect(refs.personOptions().map((o) => o.id), ['p1', 'p2', 'p3']);
    });

    test('поиск по идентификатору и запасная подпись', () async {
      final refs = make();
      await refs.load();

      expect(refs.genreTitle('g2'), 'Комедия');
      expect(refs.genreTitle('нет'), '—');
      expect(refs.hallById('h2')?.name, 'Зал VIP');
      expect(refs.hallById('нет'), isNull);
      expect(refs.movieById('m3')?.title, 'Тихая гавань');
    });

    test('страны без повторов по алфавиту', () async {
      final refs = make();
      await refs.load();

      expect(refs.countries(), ['Беларусь', 'Россия']);
    });

    test('сбой загрузки не роняет приложение и даёт текст ошибки', () async {
      final refs = make(genres: _BrokenGenres());

      await refs.load();

      expect(refs.failed, isTrue);
      expect(refs.ready, isFalse);
      expect(refs.error, isNotNull);
    });
  });

  group('Карточка записи', () {
    test('успешная загрузка', () async {
      final detail = DetailNotifier<String>(() async => 'запись');

      await detail.load();

      expect(detail.status, LoadStatus.success);
      expect(detail.item, 'запись');
    });

    test('запись не найдена — успех с пустым значением, экран покажет «не найдено»', () async {
      final detail = DetailNotifier<String>(() async => null);

      await detail.load();

      expect(detail.status, LoadStatus.success);
      expect(detail.item, isNull);
    });

    test('ошибка загрузки', () async {
      final detail = DetailNotifier<String>(() async => throw const ServerException());

      await detail.load();

      expect(detail.status, LoadStatus.error);
      expect(detail.error, contains('Не удалось загрузить запись'));
    });
  });
}
