import 'package:atrium_cinema/app.dart';
import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  Future<TestWorld> open(WidgetTester tester, {String location = '/', double width = 1280}) async {
    final world = await makeWorld(tester, role: Role.viewer);
    await pumpAtrium(tester, world, location: location, width: width);
    return world;
  }

  testWidgets('афиша показывает все фильмы и общее число записей', (tester) async {
    await open(tester);

    expect(find.text('Последний рейс'), findsOneWidget);
    expect(find.text('Лето в коммуналке'), findsOneWidget);
    expect(find.text('Тихая гавань'), findsOneWidget);
    expect(find.text('Всего записей: 3'), findsOneWidget);
  });

  testWidgets('поиск отбирает фильмы на сервере и записывается в адрес', (tester) async {
    final h = await open(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Поиск по названию или стране'), 'рейс');
    await settleSearch(tester);

    expect(find.text('Последний рейс'), findsOneWidget);
    expect(find.text('Тихая гавань'), findsNothing);
    expect(h.movies.lastQuery?.search, 'рейс');
    expect(currentLocation(tester), contains('search='));
  });

  testWidgets('пустой результат: сообщение и кнопка сброса условий', (tester) async {
    await open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Поиск по названию или стране'),
      'такого фильма нет',
    );
    await settleSearch(tester);

    expect(find.text('Фильмы не найдены. Измените поиск или фильтры.'), findsOneWidget);

    await tapText(tester, 'Сбросить условия');

    expect(find.text('Последний рейс'), findsOneWidget);
    expect(find.text('Всего записей: 3'), findsOneWidget);
  });

  testWidgets('фильтр по возрасту применяется и попадает в адрес', (tester) async {
    await open(tester);

    await pickOption(tester, 'Возраст', '16+');

    expect(find.text('Последний рейс'), findsOneWidget);
    expect(find.text('Лето в коммуналке'), findsNothing);
    expect(currentLocation(tester), contains('age=16'));
    expect(find.text('Фильтры (1)'), findsOneWidget);
  });

  testWidgets('фильтр по жанру: выбор из справочника', (tester) async {
    await open(tester);

    await pickOption(tester, 'Жанр', 'Комедия');

    expect(find.text('Лето в коммуналке'), findsOneWidget);
    expect(find.text('Последний рейс'), findsNothing);
  });

  testWidgets('фильтры восстанавливаются из адреса: ссылкой можно поделиться', (tester) async {
    final h = await open(tester, location: '/?age=6%2B&sort=year,desc');

    expect(find.text('Лето в коммуналке'), findsOneWidget);
    expect(find.text('Последний рейс'), findsNothing);
    expect(find.text('Фильтры (1)'), findsOneWidget);
    expect(h.movies.lastQuery?.filter('age'), '6+');
    expect(h.movies.lastQuery?.sortField, 'year');
    expect(h.movies.lastQuery?.sortAscending, isFalse);
  });

  testWidgets('кнопка «Сбросить» очищает фильтры', (tester) async {
    await open(tester, location: '/?age=6%2B');

    await tapText(tester, 'Сбросить');

    expect(find.text('Последний рейс'), findsOneWidget);
    expect(currentLocation(tester), isNot(contains('age=')));
  });

  group('Состояния экрана', () {
    testWidgets('загрузка: индикатор, затем данные', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      world.movies.delay = const Duration(seconds: 2);
      setScreen(tester);

      await tester.pumpWidget(AtriumApp(repositories: world.repos));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Последний рейс'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Последний рейс'), findsOneWidget);
    });

    testWidgets('пустой каталог: сообщение вместо списка', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      world.movies.rows.clear();

      await pumpAtrium(tester, world);

      expect(find.text('Фильмы не найдены. Измените поиск или фильтры.'), findsOneWidget);
      expect(find.text('Сбросить условия'), findsNothing, reason: 'условий нет, сбрасывать нечего');
    });

    testWidgets('ошибка сервера: сообщение и повтор запроса', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      world.movies.failNext = const ServerException();

      await pumpAtrium(tester, world);

      expect(find.textContaining('Не удалось загрузить список'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auto-retry-note')),
        findsNothing,
        reason: 'сервер ответил, это не обрыв связи',
      );

      await tapText(tester, 'Повторить');

      expect(find.text('Последний рейс'), findsOneWidget);
    });

    testWidgets('нет связи: экран сам повторяет запрос и обновляется', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      world.movies.failNext = const NetworkException();

      await pumpAtrium(tester, world);

      expect(find.byKey(const ValueKey('auto-retry-note')), findsOneWidget);
      expect(find.text('Последний рейс'), findsNothing);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text('Последний рейс'), findsOneWidget);
    });
  });

  testWidgets('карточка фильма ведёт на страницу фильма с сеансами', (tester) async {
    await open(tester);

    await tapText(tester, 'Последний рейс');

    expect(find.text('Пилот получает последний рейс.'), findsOneWidget);
    expect(find.text('Ближайшие сеансы'), findsOneWidget);
  });
}
