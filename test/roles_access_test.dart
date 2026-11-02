import 'package:atrium_cinema/auth/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

const _allSections = [
  'Афиша',
  'Сеансы',
  'Касса',
  'Мои билеты',
  'Билеты',
  'Заказы',
  'Фильмы',
  'Жанры',
  'Персоны',
  'Залы',
  'Пользователи',
  'Профиль',
];

const Map<Role, List<String>> _visible = {
  Role.viewer: ['Афиша', 'Сеансы', 'Мои билеты', 'Профиль'],
  Role.cashier: ['Афиша', 'Сеансы', 'Касса', 'Билеты', 'Заказы'],
  Role.admin: [
    'Афиша',
    'Сеансы',
    'Билеты',
    'Заказы',
    'Фильмы',
    'Жанры',
    'Персоны',
    'Залы',
    'Пользователи',
  ],
};

void main() {
  group('Меню показывает только разделы своей роли', () {
    for (final role in Role.values) {
      testWidgets(role.label, (tester) async {
        final world = await makeWorld(tester, role: role);
        await pumpAtrium(tester, world);

        for (final section in _allSections) {
          final expected = _visible[role]!.contains(section);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('side-nav')),
              matching: find.text(section),
            ),
            expected ? findsOneWidget : findsNothing,
            reason: '${role.label}: раздел «$section»',
          );
        }
      });
    }
  });

  group('Закрытые адреса показывают экран отказа', () {
    Future<void> expectForbidden(WidgetTester tester, Role role, String location) async {
      final world = await makeWorld(tester, role: role);
      await pumpAtrium(tester, world, location: location);

      expect(find.text('Доступ запрещён'), findsWidgets, reason: '${role.label} → $location');
      expect(find.text('У роли «${role.label}» нет доступа к этому разделу'), findsOneWidget);
    }

    testWidgets('зритель: пользователи, касса, заказы, билеты персонала, справочники', (
      tester,
    ) async {
      await expectForbidden(tester, Role.viewer, '/admin/users');
    });

    testWidgets('зритель не открывает кассу', (tester) async {
      await expectForbidden(tester, Role.viewer, '/box-office');
    });

    testWidgets('зритель не видит все заказы', (tester) async {
      await expectForbidden(tester, Role.viewer, '/orders');
    });

    testWidgets('кассир не открывает справочники и формы каталога', (tester) async {
      await expectForbidden(tester, Role.cashier, '/genres');
    });

    testWidgets('кассир не создаёт фильмы', (tester) async {
      await expectForbidden(tester, Role.cashier, '/movies/new');
    });

    testWidgets('кассир не открывает личный раздел зрителя', (tester) async {
      await expectForbidden(tester, Role.cashier, '/my/tickets');
    });

    testWidgets('администратор не открывает кассу и личный раздел зрителя', (tester) async {
      await expectForbidden(tester, Role.admin, '/box-office');
    });

    testWidgets('администратор не открывает профиль зрителя', (tester) async {
      await expectForbidden(tester, Role.admin, '/my/profile');
    });
  });

  group('Закрытые разделы открываются своей роли', () {
    testWidgets('администратор видит пользователей', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      await pumpAtrium(tester, world, location: '/admin/users');

      expect(find.text('Доступ запрещён'), findsNothing);
      expect(find.text('Иван Зрителев'), findsOneWidget);
      expect(find.text('Мария Орлова'), findsOneWidget);
    });

    testWidgets('кассир открывает кассу', (tester) async {
      final world = await makeWorld(tester, role: Role.cashier);
      await pumpAtrium(tester, world, location: '/box-office');

      expect(find.text('Доступ запрещён'), findsNothing);
      expect(find.text('Продажа билетов на месте:'), findsOneWidget);
    });

    testWidgets('зритель открывает свои билеты', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      await pumpAtrium(tester, world, location: '/my/tickets');

      expect(find.text('Доступ запрещён'), findsNothing);
      expect(find.textContaining('ряд 2, место 3'), findsWidgets);
    });
  });

  testWidgets('экран отказа ведёт на главную', (tester) async {
    final world = await makeWorld(tester, role: Role.viewer);
    await pumpAtrium(tester, world, location: '/admin/users');

    await tapText(tester, 'На главную');

    expect(currentLocation(tester), '/');
    expect(find.text('Последний рейс'), findsOneWidget);
  });

  testWidgets('гость на любом адресе попадает на экран входа', (tester) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/movies');

    expect(find.text('Вход в систему'), findsOneWidget);
    expect(currentLocation(tester), startsWith('/login'));
  });

  testWidgets('несуществующий адрес: страница не найдена', (tester) async {
    final world = await makeWorld(tester, role: Role.viewer);
    await pumpAtrium(tester, world, location: '/nowhere');

    expect(find.text('Страница не найдена'), findsWidgets);
  });

  group('Кнопки изменения скрыты от тех, кому они не положены', () {
    testWidgets('администратор видит «Добавить фильм» и действия строки', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      await pumpAtrium(tester, world, location: '/movies');

      expect(find.text('Добавить фильм'), findsOneWidget);
      expect(find.byTooltip('Изменить'), findsWidgets);
      expect(find.byTooltip('Удалить'), findsWidgets);
    });

    for (final role in [Role.viewer, Role.cashier]) {
      testWidgets('${role.label} не видит добавления, изменения и удаления', (tester) async {
        final world = await makeWorld(tester, role: role);
        await pumpAtrium(tester, world, location: '/movies');

        expect(find.text('Добавить фильм'), findsNothing);
        expect(find.byTooltip('Изменить'), findsNothing);
        expect(find.byTooltip('Удалить'), findsNothing);
        expect(find.text('Последний рейс'), findsOneWidget);
      });
    }

    testWidgets('список сеансов: добавить сеанс может только администратор', (tester) async {
      final admin = await makeWorld(tester, role: Role.admin);
      await pumpAtrium(tester, admin, location: '/screenings');
      expect(find.text('Добавить сеанс'), findsOneWidget);
    });

    testWidgets('список сеансов у зрителя без кнопок управления', (tester) async {
      final viewer = await makeWorld(tester, role: Role.viewer);
      await pumpAtrium(tester, viewer, location: '/screenings');
      expect(find.text('Добавить сеанс'), findsNothing);
      expect(find.byTooltip('Удалить'), findsNothing);
    });
  });

  test('в тестовом мире три роли с разными учётными записями', () {
    expect({for (final r in Role.values) emailOf(r)}, hasLength(3));
  });
}
