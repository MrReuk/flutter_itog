import 'package:atrium_cinema/models/list_query.dart';
import 'package:atrium_cinema/models/list_specs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Разбор адреса списка', () {
    test('пустой адрес даёт условия по умолчанию', () {
      final q = ListQuery.fromParams(kMovieSpec, const {});

      expect(q.search, isEmpty);
      expect(q.filters, isEmpty);
      expect(q.sortField, 'title');
      expect(q.sortAscending, isTrue);
      expect(q.page, 1);
      expect(q.size, 10);
      expect(q.toParams(), isEmpty);
    });

    test('поиск, фильтры, сортировка и страница читаются из параметров', () {
      final q = ListQuery.fromParams(kMovieSpec, const {
        'search': 'рейс',
        'genre': 'g3',
        'age': '16+',
        'yearFrom': '2020',
        'sort': 'year,desc',
        'page': '3',
        'size': '25',
      });

      expect(q.search, 'рейс');
      expect(q.filter('genre'), 'g3');
      expect(q.filter('age'), '16+');
      expect(q.filter('yearFrom'), '2020');
      expect(q.filter('yearTo'), isEmpty);
      expect(q.sortField, 'year');
      expect(q.sortAscending, isFalse);
      expect(q.page, 3);
      expect(q.size, 25);
    });

    test('неизвестные параметры, поля сортировки и размеры страницы игнорируются', () {
      final q = ListQuery.fromParams(kMovieSpec, const {
        'unknown': '1',
        'sort': 'password,desc',
        'page': '-4',
        'size': '999',
      });

      expect(q.filters, isEmpty);
      expect(q.sortField, 'title');
      expect(q.sortAscending, isTrue);
      expect(q.page, 1);
      expect(q.size, 10);
    });

    test('условия переводятся в адрес и обратно без потерь', () {
      final q = ListQuery.fromParams(kMovieSpec, const {
        'search': 'гавань',
        'age': '12+',
        'sort': 'durationMin,asc',
        'page': '2',
      });

      final again = ListQuery.fromParams(kMovieSpec, q.toParams());

      expect(again, q);
      expect(q.toLocation('/'), contains('search='));
    });

    test('значения по умолчанию в адрес не попадают', () {
      final q = ListQuery.initial(kScreeningSpec);

      expect(q.filter('period'), 'upcoming');
      expect(q.toParams(), isEmpty);
      expect(q.activeFilterCount, 0);
    });
  });

  group('Изменение условий', () {
    test('любое изменение, кроме смены страницы, возвращает на первую страницу', () {
      final q = ListQuery.fromParams(kMovieSpec, const {'page': '4'});

      expect(q.copyWith(search: 'а').page, 1);
      expect(q.withFilter('age', '6+').page, 1);
      expect(q.copyWith(sortField: 'year').page, 1);
      expect(q.copyWith(page: 2).page, 2);
    });

    test('пустое значение снимает фильтр или возвращает значение по умолчанию', () {
      final movies = ListQuery.initial(kMovieSpec).withFilter('age', '16+');
      expect(movies.withFilter('age', '').filters, isEmpty);

      final screenings = ListQuery.initial(kScreeningSpec).withFilter('period', 'past');
      expect(screenings.filter('period'), 'past');
      expect(screenings.withFilter('period', '').filter('period'), 'upcoming');
    });

    test('число активных фильтров не считает значения по умолчанию', () {
      var q = ListQuery.initial(kScreeningSpec);
      expect(q.activeFilterCount, 0);

      q = q.withFilter('hall', 'h1').withFilter('language', 'Дубляж');
      expect(q.activeFilterCount, 2);

      q = q.withFilter('period', 'all');
      expect(q.activeFilterCount, 3);
    });

    test('сброс убирает поиск и фильтры, но сохраняет сортировку и размер страницы', () {
      final q = ListQuery.fromParams(kMovieSpec, const {
        'search': 'а',
        'age': '12+',
        'sort': 'year,desc',
        'size': '50',
        'page': '3',
      }).reset();

      expect(q.search, isEmpty);
      expect(q.filters, isEmpty);
      expect(q.page, 1);
      expect(q.sortField, 'year');
      expect(q.sortAscending, isFalse);
      expect(q.size, 50);
    });

    test('обратная сортировка по умолчанию (заказы: новые сверху) не попадает в адрес', () {
      final q = ListQuery.initial(kOrderSpec);

      expect(q.sortField, 'created');
      expect(q.sortAscending, isFalse);
      expect(q.toParams(), isEmpty);
      expect(q.copyWith(sortAscending: true).toParams()['sort'], 'created,asc');
    });
  });
}
