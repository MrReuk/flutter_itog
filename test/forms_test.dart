import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:atrium_cinema/models/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  Future<TestWorld> admin(WidgetTester tester, String location, {double width = 1280}) async {
    final world = await makeWorld(tester, role: Role.admin);
    await pumpAtrium(tester, world, location: location, width: width);
    return world;
  }

  group('Проверка полей: ошибки показываются у полей', () {
    testWidgets('пустая форма зала', (tester) async {
      final world = await admin(tester, '/halls/new');

      await tapText(tester, 'Сохранить');

      expect(find.text('Обязательное поле'), findsNWidgets(3), reason: 'название, ряды, места');
      expect(world.halls.rows, hasLength(2), reason: 'запись не создана');
    });

    testWidgets('числа вне допустимых границ', (tester) async {
      await admin(tester, '/halls/new');

      await enterField(tester, 'Название', 'Зал 9');
      await enterField(tester, 'Количество рядов', '25');
      await enterField(tester, 'Мест в ряду', '0');
      await enterField(tester, 'Коэффициент цены', '5');
      await tapText(tester, 'Сохранить');

      expect(find.text('Допустимо от 1 до 20'), findsOneWidget);
      expect(find.text('Допустимо от 1 до 30'), findsOneWidget);
      expect(find.textContaining('Допустимо от 0.5 до 3'), findsOneWidget);
    });

    testWidgets('слишком короткое название жанра', (tester) async {
      await admin(tester, '/genres/new');

      await enterField(tester, 'Название', 'А');
      await tapText(tester, 'Сохранить');

      expect(find.text('Не короче 2 символов'), findsOneWidget);
    });

    testWidgets('фильм: год и длительность, жанры обязательны', (tester) async {
      final world = await admin(tester, '/movies/new');

      await enterField(tester, 'Название', 'Новый фильм');
      await enterField(tester, 'Год выхода', '1500');
      await enterField(tester, 'Длительность, минут', '0');
      await tapText(tester, 'Сохранить');

      expect(find.textContaining('Допустимо от 1900'), findsOneWidget);
      expect(find.textContaining('Допустимо от 1 до'), findsWidgets);
      expect(world.movies.rows, hasLength(3));
    });

    testWidgets('дата рождения персоны в неверном формате', (tester) async {
      await admin(tester, '/people/new');

      await enterField(tester, 'Имя и фамилия', 'Иван Петров');
      await enterField(tester, 'Дата рождения', '1990-05-01');
      await tapText(tester, 'Сохранить');

      expect(find.text('Введите дату в формате 31.12.2026'), findsOneWidget);
    });
  });

  group('Создание и изменение', () {
    testWidgets('корректный зал сохраняется, список обновляется', (tester) async {
      final world = await admin(tester, '/halls/new');

      await enterField(tester, 'Название', 'Зал 3');
      await enterField(tester, 'Количество рядов', '6');
      await enterField(tester, 'Мест в ряду', '10');
      await enterField(tester, 'Коэффициент цены', '1,5');
      await tapText(tester, 'Сохранить');

      expect(world.halls.rows, hasLength(3));
      expect(world.halls.rows.last.name, 'Зал 3');
      expect(world.halls.rows.last.priceFactor, 1.5);
      expect(currentLocation(tester), '/halls');
      expect(find.textContaining('Зал 3'), findsOneWidget);
    });

    testWidgets('форма изменения заполнена текущими значениями', (tester) async {
      await admin(tester, '/halls/h1/edit');

      expect(find.widgetWithText(TextFormField, 'Зал 1'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
    });

    testWidgets('изменение названия сохраняется', (tester) async {
      final world = await admin(tester, '/genres/g2/edit');

      await enterField(tester, 'Название', 'Комедия положений');
      await tapText(tester, 'Сохранить');

      expect(world.genres.rows.firstWhere((g) => g.id == 'g2').title, 'Комедия положений');
      expect(currentLocation(tester), '/genres');
    });

    testWidgets('фильм со связями: жанры выбираются из списка', (tester) async {
      final world = await admin(tester, '/movies/new');

      await enterField(tester, 'Название', 'Новый фильм');
      await enterField(tester, 'Год выхода', '2026');
      await enterField(tester, 'Длительность, минут', '100');
      await pickOption(tester, 'Возрастное ограничение', '12+');
      await tapText(tester, 'Драма');
      await tapText(tester, 'Комедия');
      await tapText(tester, 'Сохранить');

      final created = world.movies.rows.last;
      expect(created.title, 'Новый фильм');
      expect(created.genreIds, containsAll(['g1', 'g2']));
      expect(created.ageRating, '12+');
    });

    testWidgets('сеанс: фильм и зал выбираются из выпадающих списков', (tester) async {
      final world = await admin(tester, '/screenings/new');

      await pickOption(tester, 'Фильм', 'Тихая гавань (2024)');
      await pickOption(tester, 'Зал', 'Зал VIP (VIP)');
      await enterField(tester, 'Начало', '01.01.2031 12:00');
      await tapText(tester, 'Сохранить');

      final created = world.screenings.rows.last;
      expect(created.movieId, 'm3');
      expect(created.hallId, 'h2');
      expect(formatCinemaDateTime(created.startsAt), '01.01.2031 12:00');
    });
  });

  group('Ответ сервера с ошибкой показывается у поля', () {
    testWidgets('жанр с таким названием уже есть', (tester) async {
      final world = await admin(tester, '/genres/new');
      world.genres.saveError = const ValidationException('Failed to create record.', {
        'title': 'Жанр с таким названием уже существует.',
      });

      await enterField(tester, 'Название', 'Драма');
      await tapText(tester, 'Сохранить');

      expect(find.text('Жанр с таким названием уже существует.'), findsOneWidget);
      expect(currentLocation(tester), '/genres/new');
    });

    testWidgets('зал занят: конфликт расписания показан у поля «Начало»', (tester) async {
      final world = await admin(tester, '/screenings/s3/edit');
      final busyStart = world.data.screenings.first.startsAt;

      await enterField(tester, 'Начало', formatCinemaDateTime(busyStart));
      await tapText(tester, 'Сохранить');

      expect(find.text('Зал занят в это время другим сеансом.'), findsOneWidget);
      expect(currentLocation(tester), '/screenings/s3/edit');
    });
  });

  group('Несохранённые изменения', () {
    testWidgets('уход из формы с правками запрашивает подтверждение', (tester) async {
      await admin(tester, '/halls/h1/edit');

      await enterField(tester, 'Название', 'Другое имя');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Выйти без сохранения?'), findsOneWidget);

      await tapText(tester, 'Остаться');

      expect(find.text('Выйти без сохранения?'), findsNothing);
      expect(find.text('Редактирование зала'), findsOneWidget);
    });

    testWidgets('без правок форма закрывается сразу', (tester) async {
      await admin(tester, '/halls/h1/edit');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Выйти без сохранения?'), findsNothing);
    });
  });

  testWidgets('запись не найдена: сообщение вместо формы', (tester) async {
    await admin(tester, '/halls/nope/edit');

    expect(find.text('Зал не найден'), findsOneWidget);
  });

  testWidgets('форма на телефоне (360 px) без переполнения', (tester) async {
    await admin(tester, '/halls/new', width: 360);

    await tapText(tester, 'Сохранить');

    expect(tester.takeException(), isNull);
    expect(find.text('Обязательное поле'), findsWidgets);
  });

  group('Пользователи (только администратор)', () {
    testWidgets('создание кассира с паролем и ролью', (tester) async {
      final world = await admin(tester, '/admin/users/new');

      await enterField(tester, 'Имя', 'Новый Кассир');
      await enterField(tester, 'Почта', 'newcashier@atrium.test');
      await enterField(tester, 'Пароль', 'Abcdef1!');
      await pickOption(tester, 'Роль', 'Кассир');
      await tapText(tester, 'Сохранить');

      final created = world.users.rows.last;
      expect(created.email, 'newcashier@atrium.test');
      expect(created.role, Role.cashier);
    });

    testWidgets('занятая почта: ошибка у поля', (tester) async {
      await admin(tester, '/admin/users/new');

      await enterField(tester, 'Имя', 'Дубль');
      await enterField(tester, 'Почта', 'viewer@atrium.test');
      await enterField(tester, 'Пароль', 'Abcdef1!');
      await pickOption(tester, 'Роль', 'Зритель');
      await tapText(tester, 'Сохранить');

      expect(find.text('Эта почта уже используется.'), findsOneWidget);
    });
  });
}
