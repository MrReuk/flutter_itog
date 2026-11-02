import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/models/ticket.dart';
import 'package:atrium_cinema/state/booking_notifier.dart';
import 'package:atrium_cinema/state/load_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late TestWorld world;

  BookingNotifier booking(String screeningId, {String? customerId = 'u1'}) {
    return BookingNotifier(
      screeningId: screeningId,
      screenings: world.screenings,
      seats: world.screenings,
      orders: world.orders,
      customerId: customerId,
    );
  }

  setUp(() async {
    world = await TestWorld.create(role: Role.viewer);
  });

  group('Схема зала', () {
    test('загружает сеанс и занятые места', () async {
      final b = booking('s1');

      await b.load();

      expect(b.status, LoadStatus.success);
      expect(b.screening?.movieTitle, 'Последний рейс');
      expect(b.isTaken(2, 3), isTrue, reason: 'в тестовых данных этот билет уже продан');
      expect(b.isTaken(1, 1), isFalse);
    });

    test('несуществующий сеанс — ошибка с понятным текстом', () async {
      final b = booking('nope');

      await b.load();

      expect(b.status, LoadStatus.error);
      expect(b.error, 'Сеанс не найден.');
    });

    test('начавшийся сеанс распознаётся по времени', () async {
      final past = booking('s0');
      final future = booking('s1');
      await past.load();
      await future.load();

      expect(past.isStarted(world.data.now), isTrue);
      expect(future.isStarted(world.data.now), isFalse);
    });
  });

  group('Выбор мест и цена', () {
    test('цена зависит от категории: полный, детский, студенческий', () async {
      final b = booking('s1');
      await b.load();

      expect(b.priceFor(TicketCategory.full), 400);
      expect(b.priceFor(TicketCategory.child), 200);
      expect(b.priceFor(TicketCategory.student), 280);
    });

    test('в VIP-зале утром действует коэффициент зала и скидка', () async {
      final b = booking('s2');
      await b.load();

      expect(b.priceFor(TicketCategory.full), 480, reason: '300 × 2 × 0,8');
    });

    test('место выбирается и снимается, занятое выбрать нельзя', () async {
      final b = booking('s1');
      await b.load();

      b.toggle(1, 1);
      expect(b.isChosen(1, 1), isTrue);
      b.toggle(1, 1);
      expect(b.isChosen(1, 1), isFalse);

      b.toggle(2, 3);
      expect(b.isChosen(2, 3), isFalse);
    });

    test('итог считается по категориям выбранных мест', () async {
      final b = booking('s1');
      await b.load();

      b.toggle(1, 1);
      b.toggle(1, 2);
      b.toggle(1, 3);
      b.setCategory(1, 2, TicketCategory.child);
      b.setCategory(1, 3, TicketCategory.student);

      expect(b.total, 400 + 200 + 280);
      expect(b.chosen, hasLength(3));
    });

    test('категорию нельзя задать для невыбранного места', () async {
      final b = booking('s1');
      await b.load();

      b.setCategory(1, 1, TicketCategory.child);

      expect(b.chosen, isEmpty);
    });

    test('очистка снимает весь выбор', () async {
      final b = booking('s1');
      await b.load();
      b.toggle(1, 1);

      b.clear();

      expect(b.chosen, isEmpty);
      expect(b.total, 0);
    });
  });

  group('Оформление', () {
    test('успешная покупка создаёт заказ и билеты, выбор очищается', () async {
      final b = booking('s1');
      await b.load();
      b.toggle(3, 4);
      b.toggle(3, 5);
      b.setCategory(3, 5, TicketCategory.student);

      final ok = await b.submit();

      expect(ok, isTrue);
      expect(b.result?.tickets, hasLength(2));
      expect(b.result?.order.total, 400 + 280);
      expect(b.chosen, isEmpty);
      expect(b.submitting, isFalse);
      expect(world.tickets.isTaken('s1', 3, 4), isTrue);
      expect(world.orders.rows.last.customerId, 'u1');
    });

    test('пустой выбор не отправляется', () async {
      final b = booking('s1');
      await b.load();

      expect(await b.submit(), isFalse);
      expect(b.result, isNull);
    });

    test(
      'место, которое успели купить, даёт конфликт: схема обновляется, остальной выбор сохраняется',
      () async {
        final b = booking('s1');
        await b.load();
        b.toggle(1, 1);
        b.toggle(1, 2);
        world.tickets.rows.add(
          const Ticket(
            id: 'tx',
            orderId: 'ox',
            screeningId: 's1',
            row: 1,
            seat: 1,
            category: TicketCategory.full,
            price: 400,
            status: TicketStatus.sold,
          ),
        );

        final ok = await b.submit();

        expect(ok, isFalse);
        expect(b.submitError, contains('Это место уже куплено.'));
        expect(b.submitError, contains('Схема зала обновлена'));
        expect(b.isTaken(1, 1), isTrue);
        expect(b.isChosen(1, 1), isFalse);
        expect(b.isChosen(1, 2), isTrue);
        expect(b.result, isNull);
      },
    );

    test('после результата можно закрыть экран подтверждения', () async {
      final b = booking('s1');
      await b.load();
      b.toggle(4, 4);
      await b.submit();

      b.dismissResult();

      expect(b.result, isNull);
    });

    test('кассир оформляет заказ без покупателя', () async {
      final b = booking('s1', customerId: null);
      await b.load();
      b.toggle(5, 5);

      await b.submit();

      expect(world.orders.rows.last.customerId, isEmpty);
    });
  });

  test('после удаления уведомления не приходят', () async {
    final b = booking('s1');
    await b.load();
    b.dispose();

    b.toggle(1, 1);

    expect(b.chosen, hasLength(1));
  });
}
