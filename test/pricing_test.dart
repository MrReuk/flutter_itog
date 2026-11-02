import 'package:atrium_cinema/models/format.dart';
import 'package:atrium_cinema/models/pricing.dart';
import 'package:atrium_cinema/models/ticket.dart';
import 'package:atrium_cinema/repositories/screening_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final evening = DateTime.utc(2026, 11, 5, 15);
  final morning = DateTime.utc(2026, 11, 5, 7);

  int price(int base, double hall, TicketCategory c, DateTime at) =>
      ticketPrice(basePrice: base, hallFactor: hall, category: c, startsAt: at);

  group('Цена билета', () {
    test('полный билет в обычном зале стоит базовую цену', () {
      expect(price(400, 1, TicketCategory.full, evening), 400);
    });

    test('детский билет вдвое дешевле, студенческий дешевле на 30%', () {
      expect(price(400, 1, TicketCategory.child, evening), 200);
      expect(price(400, 1, TicketCategory.student, evening), 280);
    });

    test('коэффициент зала увеличивает цену (VIP ×2)', () {
      expect(price(300, 2, TicketCategory.full, evening), 600);
      expect(price(300, 1.6, TicketCategory.full, evening), 480);
    });

    test('утром действует скидка 20%', () {
      expect(price(300, 1, TicketCategory.full, morning), 240);
      expect(price(300, 1, TicketCategory.child, morning), 120);
    });

    test('цена округляется до целого рубля', () {
      expect(price(350, 1.2, TicketCategory.student, evening), 294);
      expect(price(333, 1, TicketCategory.student, evening), 233);
    });

    test('граница утра: 11:59 по Москве со скидкой, 12:00 без скидки', () {
      expect(isMorningScreening(DateTime.utc(2026, 11, 5, 8, 59)), isTrue);
      expect(isMorningScreening(DateTime.utc(2026, 11, 5, 9)), isFalse);
    });

    test('утро определяется по московскому времени, а не по часовому поясу компьютера', () {
      expect(isMorningScreening(DateTime.utc(2026, 11, 4, 21, 30)), isTrue);
    });
  });

  group('Расписание', () {
    test('сеанс заканчивается через длительность фильма и 20 минут', () {
      final end = screeningEnd(evening, 118);

      expect(end.difference(evening), const Duration(minutes: 138));
    });

    test('пересечение: общие минуты в одном зале', () {
      final a = DateTime.utc(2026, 11, 5, 10);
      final b = DateTime.utc(2026, 11, 5, 12);

      expect(
        intervalsOverlap(a, b, DateTime.utc(2026, 11, 5, 11), DateTime.utc(2026, 11, 5, 13)),
        isTrue,
      );
      expect(
        intervalsOverlap(a, b, DateTime.utc(2026, 11, 5, 9), DateTime.utc(2026, 11, 5, 11)),
        isTrue,
      );
      expect(
        intervalsOverlap(a, b, DateTime.utc(2026, 11, 5, 10, 30), DateTime.utc(2026, 11, 5, 11)),
        isTrue,
      );
    });

    test('сеансы встык не пересекаются', () {
      final a = DateTime.utc(2026, 11, 5, 10);
      final b = DateTime.utc(2026, 11, 5, 12);

      expect(intervalsOverlap(a, b, b, DateTime.utc(2026, 11, 5, 14)), isFalse);
      expect(intervalsOverlap(a, b, DateTime.utc(2026, 11, 5, 8), a), isFalse);
    });
  });

  group('Формат', () {
    test('рубли с неразрывными пробелами между разрядами', () {
      expect(formatRub(0), '0 ₽');
      expect(formatRub(950), '950 ₽');
      expect(formatRub(1200), '1 200 ₽');
      expect(formatRub(1234567), '1 234 567 ₽');
    });

    test('время показывается московское', () {
      final moment = DateTime.utc(2026, 11, 5, 15, 30);

      expect(formatCinemaClock(moment), '18:30');
      expect(formatCinemaDate(moment), '05.11.2026');
      expect(formatCinemaDateTime(moment), '05.11.2026 18:30');
    });

    test('поля формы по Москве переводятся в момент времени и обратно', () {
      final fields = DateTime(2026, 11, 5, 18, 30);

      final moment = fromCinemaFields(fields);

      expect(moment, DateTime.utc(2026, 11, 5, 15, 30));
      expect(formatCinemaDateTime(moment), '05.11.2026 18:30');
    });

    test('сутки по Москве начинаются в 21:00 UTC предыдущего дня', () {
      final range = dayRange('2026-11-05');

      expect(range.from, '2026-11-04 21:00:00.000Z');
      expect(range.to, '2026-11-05 21:00:00.000Z');
      expect(isoCinemaDate(DateTime.utc(2026, 11, 4, 22)), '2026-11-05');
    });

    test('неверная дата даёт пустой диапазон', () {
      expect(dayRange('вчера'), (from: '', to: ''));
    });
  });
}
