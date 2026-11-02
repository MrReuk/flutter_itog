import 'package:atrium_cinema/app.dart';
import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:atrium_cinema/models/genre.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  Future<TestWorld> admin(
    WidgetTester tester, {
    String location = '/genres',
    int genres = 3,
    double width = 1280,
  }) async {
    final world = await makeWorld(tester, role: Role.admin);
    for (var i = 4; i <= genres; i++) {
      world.genres.rows.add(Genre(id: 'g$i', title: 'Жанр ${i.toString().padLeft(2, '0')}'));
    }
    await pumpAtrium(tester, world, location: location, width: width);
    return world;
  }

  group('Четыре состояния списка', () {
    testWidgets('загрузка → данные', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      world.genres.delay = const Duration(seconds: 2);
      setScreen(tester);

      await tester.pumpWidget(AtriumApp(repositories: world.repos, initialLocation: '/genres'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Драма'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Драма'), findsOneWidget);
    });

    testWidgets('пусто: сообщение', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      world.genres.rows.clear();
      await pumpAtrium(tester, world, location: '/genres');

      expect(find.text('Жанры не найдены.'), findsOneWidget);
    });

    testWidgets('ошибка: сообщение и кнопка «Повторить»', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      world.genres.failNext = const ServerException();
      await pumpAtrium(tester, world, location: '/genres');

      expect(find.textContaining('Не удалось загрузить список'), findsOneWidget);

      await tapText(tester, 'Повторить');

      expect(find.text('Драма'), findsOneWidget);
    });

    testWidgets('данные: строки таблицы', (tester) async {
      await admin(tester);

      expect(find.text('Драма'), findsOneWidget);
      expect(find.text('Комедия'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
    });
  });

  group('Поиск, сортировка и страницы выполняются на сервере', () {
    testWidgets('поиск по названию', (tester) async {
      final world = await admin(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Поиск по названию'), 'ком');
      await settleSearch(tester);

      expect(find.text('Комедия'), findsOneWidget);
      expect(find.text('Драма'), findsNothing);
      expect(world.genres.lastQuery?.search, 'ком');
      expect(currentLocation(tester), contains('search=%D0%BA%D0%BE%D0%BC'));
    });

    testWidgets('страницы: 15 записей по 10', (tester) async {
      final world = await admin(tester, genres: 15);

      expect(find.text('Всего записей: 15'), findsOneWidget);
      expect(find.text('Страница 1 из 2'), findsOneWidget);
      expect(dataRowCount(tester), 10);

      await tapTooltip(tester, 'Следующая');

      expect(find.text('Страница 2 из 2'), findsOneWidget);
      expect(dataRowCount(tester), 5);
      expect(currentLocation(tester), contains('page=2'));
      expect(world.genres.lastQuery?.page, 2);
    });

    testWidgets('страница из адреса открывается сразу', (tester) async {
      await admin(tester, location: '/genres?page=2', genres: 15);

      expect(find.text('Страница 2 из 2'), findsOneWidget);
    });

    testWidgets('размер страницы меняется на 25', (tester) async {
      final world = await admin(tester, genres: 15);

      await pickOption(tester, '10', '25');

      expect(dataRowCount(tester), 15);
      expect(world.genres.lastQuery?.size, 25);
      expect(currentLocation(tester), contains('size=25'));
    });

    testWidgets('сортировка по заголовку столбца меняет направление', (tester) async {
      final world = await admin(tester);

      await tapText(tester, 'Название');

      expect(world.genres.lastQuery?.sortAscending, isFalse);
      expect(currentLocation(tester), contains('sort=title%2Cdesc'));
    });

    testWidgets('фильтр персон по стране', (tester) async {
      await admin(tester, location: '/people');

      await pickOption(tester, 'Страна', 'Беларусь');

      expect(find.text('Ольга Рябина'), findsOneWidget);
      expect(find.text('Алексей Громов'), findsNothing);
      expect(currentLocation(tester), contains('country='));
    });

    testWidgets('фильтры залов и сеансов: несколько условий вместе', (tester) async {
      final world = await admin(tester, location: '/screenings');

      await pickOption(tester, 'Зал', 'Зал VIP (VIP)');

      expect(world.screenings.lastQuery?.filter('hall'), 'h2');
      expect(world.screenings.lastQuery?.filter('period'), 'upcoming');
      expect(find.text('Лето в коммуналке'), findsOneWidget);
    });
  });

  group('Удаление', () {
    testWidgets('удаление строки с подтверждением', (tester) async {
      final world = await admin(tester);

      await tester.tap(find.byTooltip('Удалить').first);
      await tester.pumpAndSettle();
      expect(find.text('Удалить запись?'), findsOneWidget);
      await tapText(tester, 'Удалить');

      expect(world.genres.rows, hasLength(2));
    });

    testWidgets('отказ в подтверждении оставляет запись', (tester) async {
      final world = await admin(tester);

      await tester.tap(find.byTooltip('Удалить').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Отмена');

      expect(world.genres.rows, hasLength(3));
    });

    testWidgets('запись со связями не удаляется: понятное объяснение', (tester) async {
      final world = await admin(tester);
      world.genres.protectedIds.add('g1');

      await tester.tap(find.byTooltip('Удалить').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Удалить');

      expect(find.text('Действие невозможно'), findsOneWidget);
      expect(find.textContaining('используется'), findsOneWidget);
      expect(world.genres.rows, hasLength(3));
    });

    testWidgets('массовое удаление выбранных строк', (tester) async {
      final world = await admin(tester);

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Выбрано: 2'), findsOneWidget);

      await tapText(tester, 'Удалить выбранные');
      await tapText(tester, 'Удалить');

      expect(world.genres.rows, hasLength(1));
    });
  });

  testWidgets('на узком экране таблица заменяется карточками с сортировкой', (tester) async {
    await admin(tester, width: 600);

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Сортировка:'), findsOneWidget);
    expect(find.text('Драма'), findsOneWidget);
  });
}
