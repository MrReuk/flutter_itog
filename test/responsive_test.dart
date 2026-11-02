import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/core/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _widths = [360.0, 768.0, 1280.0, 1920.0];

void main() {
  group('Меню подстраивается под ширину окна', () {
    testWidgets('360 px: нижняя панель, боковой полосы нет', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      await pumpAtrium(tester, world, width: 360);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('768 px: боковая полоса с подписями под значками', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      await pumpAtrium(tester, world, width: 768);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('1280 и 1920 px: раскрытая боковая полоса', (tester) async {
      for (final width in [1280.0, 1920.0]) {
        final world = await makeWorld(tester, role: Role.viewer);
        await pumpAtrium(tester, world, width: width);

        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isTrue, reason: '$width px');
      }
    });

    testWidgets('у администратора разделов больше пяти: лишние уходят в «Ещё»', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      await pumpAtrium(tester, world, width: 360);

      expect(find.text('Ещё'), findsOneWidget);
    });
  });

  group('Содержимое не растягивается на весь монитор', () {
    testWidgets('1920 px: ширина страницы не больше предела', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      await pumpAtrium(tester, world, width: 1920);

      final size = tester.getSize(find.byKey(const ValueKey('page-content')));
      expect(size.width, lessThanOrEqualTo(kContentMaxWidth));
    });
  });

  group('Экраны без переполнения на всех ширинах', () {
    for (final width in _widths) {
      testWidgets('афиша ${width.toInt()} px', (tester) async {
        final world = await makeWorld(tester, role: Role.viewer);
        await pumpAtrium(tester, world, width: width);

        expect(tester.takeException(), isNull);
        expect(find.text('Последний рейс'), findsOneWidget);
      });

      testWidgets('список залов (администратор) ${width.toInt()} px', (tester) async {
        final world = await makeWorld(tester, role: Role.admin);
        await pumpAtrium(tester, world, location: '/halls', width: width);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Зал VIP'), findsOneWidget);
      });

      testWidgets('форма фильма ${width.toInt()} px', (tester) async {
        final world = await makeWorld(tester, role: Role.admin);
        await pumpAtrium(tester, world, location: '/movies/m1/edit', width: width);

        expect(tester.takeException(), isNull);
        expect(find.text('Редактирование фильма'), findsOneWidget);
      });

      testWidgets('схема зала ${width.toInt()} px', (tester) async {
        final world = await makeWorld(tester, role: Role.viewer);
        await pumpAtrium(tester, world, location: '/screenings/s2', width: width);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('seat-1-1')), findsOneWidget);
      });

      testWidgets('вход ${width.toInt()} px', (tester) async {
        final world = await makeWorld(tester, role: null);
        await pumpAtrium(tester, world, location: '/login', width: width);

        expect(tester.takeException(), isNull);
        expect(find.text('Вход в систему'), findsOneWidget);
      });
    }
  });

  group('Таблица или карточки по месту, отведённому списку', () {
    testWidgets('1280 px: таблица', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      await pumpAtrium(tester, world, location: '/halls', width: 1280);

      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('360 px: карточки', (tester) async {
      final world = await makeWorld(tester, role: Role.admin);
      await pumpAtrium(tester, world, location: '/halls', width: 360);

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);
    });
  });

  group('Фильтры на узком экране', () {
    testWidgets('360 px: фильтры свёрнуты, открываются кнопкой', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      await pumpAtrium(tester, world, width: 360);

      expect(find.text('Возраст'), findsNothing);

      await tapTooltip(tester, 'Фильтры');

      expect(find.text('Возраст'), findsOneWidget);
    });

    testWidgets('1280 px: фильтры открыты сразу', (tester) async {
      final world = await makeWorld(tester, role: Role.viewer);
      await pumpAtrium(tester, world, width: 1280);

      expect(find.text('Возраст'), findsOneWidget);
    });
  });
}
