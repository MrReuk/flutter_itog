import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/models/order.dart';
import 'package:atrium_cinema/models/ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  Future<TestWorld> open(
    WidgetTester tester,
    Role role,
    String location, {
    double width = 1280,
  }) async {
    final world = await makeWorld(tester, role: role);
    await pumpAtrium(tester, world, location: location, width: width);
    return world;
  }

  group('Заказы (кассир)', () {
    testWidgets('список: номер, покупатель и сумма', (tester) async {
      await open(tester, Role.cashier, '/orders');

      expect(find.text('o1'), findsOneWidget);
      expect(find.text('Иван Зрителев'), findsOneWidget);
      expect(find.text('Всего записей: 1'), findsOneWidget);
    });

    testWidgets('фильтр «Канал продажи» отбирает заказы на сервере', (tester) async {
      final world = await open(tester, Role.cashier, '/orders');

      await pickOption(tester, 'Канал продажи', 'Касса');

      expect(world.orders.lastQuery?.filter('channel'), 'box');
      expect(find.text('Заказы не найдены. Измените поиск или фильтры.'), findsOneWidget);
    });

    testWidgets('карточка заказа показывает билеты', (tester) async {
      await open(tester, Role.cashier, '/orders/o1');

      expect(find.text('Номер заказа'), findsOneWidget);
      expect(find.text('Ряд 2, место 3'), findsOneWidget);
      expect(find.text('Вернуть заказ'), findsOneWidget);
      expect(
        find.text('Удалить'),
        findsNothing,
        reason: 'удалять заказы может только администратор',
      );
    });

    testWidgets('возврат заказа: места освобождаются, статус меняется', (tester) async {
      final world = await open(tester, Role.cashier, '/orders/o1');

      await tapText(tester, 'Вернуть заказ');
      expect(find.text('Вернуть заказ?'), findsOneWidget);
      await tapText(tester, 'Вернуть');

      expect(world.orders.rows.first.status, OrderStatus.refunded);
      expect(world.tickets.isTaken('s1', 2, 3), isFalse);
      expect(find.text('Возвращён'), findsWidgets);
      expect(find.text('Вернуть заказ'), findsNothing);
    });

    testWidgets('отметка билета как использованного', (tester) async {
      final world = await open(tester, Role.cashier, '/orders/o1');

      await tapTooltip(tester, 'Отметить как использованный');

      expect(world.tickets.rows.first.status, TicketStatus.used);
      expect(find.textContaining('Использован'), findsWidgets);
    });

    testWidgets('администратор может удалить заказ', (tester) async {
      final world = await open(tester, Role.admin, '/orders/o1');

      await tapText(tester, 'Удалить');
      await tapLast(tester, 'Удалить');

      expect(world.orders.rows, isEmpty);
      expect(currentLocation(tester), '/orders');
    });

    testWidgets('несуществующий заказ', (tester) async {
      await open(tester, Role.cashier, '/orders/nope');

      expect(find.text('Заказ не найден'), findsOneWidget);
    });
  });

  group('Билеты', () {
    testWidgets('зритель видит свой билет и может вернуть его до начала сеанса', (tester) async {
      final world = await open(tester, Role.viewer, '/my/tickets');

      expect(find.text('ряд 2, место 3'), findsOneWidget);

      await tapTooltip(tester, 'Вернуть билет');
      expect(find.text('Вернуть билет?'), findsOneWidget);
      await tapText(tester, 'Вернуть');

      expect(world.tickets.rows.first.status, TicketStatus.returned);
    });

    testWidgets('зритель не может отметить билет использованным', (tester) async {
      await open(tester, Role.viewer, '/my/tickets');

      expect(find.byTooltip('Отметить как использованный'), findsNothing);
    });

    testWidgets('контролёр (кассир) отмечает билет в общем списке', (tester) async {
      final world = await open(tester, Role.cashier, '/tickets');

      await tapTooltip(tester, 'Отметить как использованный');

      expect(world.tickets.rows.first.status, TicketStatus.used);
    });

    testWidgets('фильтр билетов по статусу', (tester) async {
      await open(tester, Role.cashier, '/tickets');

      await pickOption(tester, 'Статус', 'Возвращён');

      expect(find.text('Билеты не найдены. Измените поиск или фильтры.'), findsOneWidget);
    });
  });

  group('Касса', () {
    testWidgets('кассир видит расписание с выбором дня и продаёт билет', (tester) async {
      await open(tester, Role.cashier, '/box-office');

      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('Завтра'), findsOneWidget);
      expect(find.text('Все предстоящие'), findsOneWidget);
    });

    testWidgets('выбор дня записывается в адрес', (tester) async {
      await open(tester, Role.cashier, '/box-office');

      await tapText(tester, 'Завтра');

      expect(currentLocation(tester), contains('date='));
    });
  });

  group('Профиль зрителя', () {
    testWidgets('телефон и студенческий статус сохраняются', (tester) async {
      final world = await open(tester, Role.viewer, '/my/profile');

      expect(find.widgetWithText(TextFormField, '+7 900 123-45-67'), findsWidgets);

      await enterField(tester, 'Телефон', '+7 911 222-33-44');
      await pickOption(tester, 'Студент (студенческий билет со скидкой)', 'Да');
      await tapText(tester, 'Сохранить');

      expect(world.profiles.lastSaved?.phone, '+7 911 222-33-44');
      expect(world.profiles.lastSaved?.student, isTrue);
    });

    testWidgets('телефон с буквами и слишком короткий номер', (tester) async {
      await open(tester, Role.viewer, '/my/profile');

      await enterField(tester, 'Телефон', '12345');
      await tapText(tester, 'Сохранить');

      expect(find.text('В номере должно быть от 10 до 15 цифр'), findsOneWidget);
    });
  });
}
