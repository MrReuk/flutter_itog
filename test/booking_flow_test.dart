import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/models/format.dart';
import 'package:atrium_cinema/models/ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  Future<TestWorld> open(
    WidgetTester tester,
    Role role, {
    String screening = 's1',
    double width = 1280,
  }) async {
    final world = await makeWorld(tester, role: role);
    await pumpAtrium(tester, world, location: '/screenings/$screening', width: width);
    return world;
  }

  Finder seat(int row, int number) => find.byKey(ValueKey('seat-$row-$number'));

  Text total(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('order-total')));

  testWidgets('схема зала: места, занятое место нельзя выбрать', (tester) async {
    await open(tester, Role.viewer);

    expect(find.text('Выбор мест'), findsOneWidget);
    expect(seat(1, 1), findsOneWidget);
    expect(seat(5, 8), findsOneWidget, reason: 'зал 5 × 8');
    expect(seat(6, 1), findsNothing);

    await tester.tap(seat(2, 3));
    await tester.pumpAndSettle();

    expect(find.text('Выберите места на схеме зала.'), findsOneWidget);
  });

  testWidgets('выбор мест, категория билета и итоговая сумма', (tester) async {
    await open(tester, Role.viewer);

    await tester.tap(seat(1, 1));
    await tester.tap(seat(1, 2));
    await tester.pumpAndSettle();

    expect(total(tester).data, formatRub(800));
    expect(find.byKey(const ValueKey('line-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-1-2')), findsOneWidget);

    await tester.tap(seat(1, 2));
    await tester.pumpAndSettle();

    expect(total(tester).data, formatRub(400));
  });

  testWidgets('смена категории пересчитывает цену', (tester) async {
    await open(tester, Role.viewer);
    await tester.tap(seat(1, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Полный').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Детский').last);
    await tester.pumpAndSettle();

    expect(total(tester).data, formatRub(200));
  });

  testWidgets('зритель покупает билеты: подтверждение, заказ, экран результата', (tester) async {
    final world = await open(tester, Role.viewer);
    await tester.tap(seat(3, 4));
    await tester.tap(seat(3, 5));
    await tester.pumpAndSettle();

    await tapKey(tester, 'buy-button');
    expect(find.text('Оформить заказ?'), findsOneWidget);
    expect(find.textContaining('Билетов: 2'), findsOneWidget);
    await tapText(tester, 'Оформить');

    expect(find.byKey(const ValueKey('order-done')), findsOneWidget);
    expect(find.text('Заказ оформлен'), findsOneWidget);
    expect(world.tickets.isTaken('s1', 3, 4), isTrue);
    expect(world.tickets.isTaken('s1', 3, 5), isTrue);
    expect(world.orders.rows.last.customerId, 'u1');
    expect(find.text('Мои билеты'), findsWidgets);
  });

  testWidgets('отказ в подтверждении ничего не покупает', (tester) async {
    final world = await open(tester, Role.viewer);
    await tester.tap(seat(3, 4));
    await tester.pumpAndSettle();

    await tapKey(tester, 'buy-button');
    await tapText(tester, 'Отмена');

    expect(find.byKey(const ValueKey('order-done')), findsNothing);
    expect(world.tickets.isTaken('s1', 3, 4), isFalse);
  });

  testWidgets('место купили, пока выбирали: сообщение, схема обновлена, остальной выбор цел', (
    tester,
  ) async {
    final world = await open(tester, Role.viewer);
    await tester.tap(seat(4, 1));
    await tester.tap(seat(4, 2));
    await tester.pumpAndSettle();
    world.tickets.rows.add(
      const Ticket(
        id: 'tx',
        orderId: 'ox',
        screeningId: 's1',
        row: 4,
        seat: 1,
        category: TicketCategory.full,
        price: 400,
        status: TicketStatus.sold,
      ),
    );

    await tapKey(tester, 'buy-button');
    await tapText(tester, 'Оформить');

    expect(find.byKey(const ValueKey('order-done')), findsNothing);
    expect(find.textContaining('Это место уже куплено.'), findsOneWidget);
    expect(find.byKey(const ValueKey('line-4-1')), findsNothing);
    expect(find.byKey(const ValueKey('line-4-2')), findsOneWidget);
  });

  testWidgets('начавшийся сеанс: продажа закрыта', (tester) async {
    await open(tester, Role.viewer, screening: 's0');

    expect(find.text('Сеанс уже начался, продажа билетов закрыта.'), findsOneWidget);
    await tester.tap(seat(1, 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('line-1-1')), findsNothing);
  });

  testWidgets('кассир оформляет продажу на месте и открывает заказ', (tester) async {
    final world = await open(tester, Role.cashier);
    await tester.tap(seat(2, 1));
    await tester.pumpAndSettle();

    expect(find.text('Оформить продажу'), findsOneWidget);
    await tapKey(tester, 'buy-button');
    await tapText(tester, 'Оформить');

    expect(find.byKey(const ValueKey('order-done')), findsOneWidget);
    expect(world.orders.rows.last.customerId, isEmpty, reason: 'в кассе покупатель не указывается');

    await tapText(tester, 'Открыть заказ');

    expect(currentLocation(tester), startsWith('/orders/'));
  });

  testWidgets('администратор видит схему, но купить не может', (tester) async {
    await open(tester, Role.admin);

    expect(find.textContaining('Покупка билетов недоступна для вашей роли'), findsOneWidget);
    await tester.tap(seat(1, 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('line-1-1')), findsNothing);
    expect(find.byKey(const ValueKey('buy-button')), findsNothing);
  });

  testWidgets('несуществующий сеанс', (tester) async {
    await open(tester, Role.viewer, screening: 'nope');

    expect(find.text('Сеанс не найден.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('на телефоне (360 px) места выбираются и билет покупается', (tester) async {
    final world = await open(tester, Role.viewer, width: 360);

    await tester.ensureVisible(seat(1, 1));
    await tester.tap(seat(1, 1));
    await tester.pumpAndSettle();
    await tapKey(tester, 'buy-button');
    await tapText(tester, 'Оформить');

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('order-done')), findsOneWidget);
    expect(world.tickets.isTaken('s1', 1, 1), isTrue);
  });

  testWidgets('время сеанса показывается по Москве', (tester) async {
    final world = await open(tester, Role.viewer);

    final start = world.data.screenings.first.startsAt;
    expect(find.textContaining(formatCinemaClock(start)), findsWidgets);
  });
}
