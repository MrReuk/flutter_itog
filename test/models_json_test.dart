import 'package:atrium_cinema/auth/app_user.dart';
import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/models/genre.dart';
import 'package:atrium_cinema/models/hall.dart';
import 'package:atrium_cinema/models/json_helpers.dart';
import 'package:atrium_cinema/models/movie.dart';
import 'package:atrium_cinema/models/order.dart';
import 'package:atrium_cinema/models/person.dart';
import 'package:atrium_cinema/models/screening.dart';
import 'package:atrium_cinema/models/ticket.dart';
import 'package:atrium_cinema/models/viewer_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Вспомогательные разборщики', () {
    test('числа из разных представлений', () {
      expect(jsonInt(5), 5);
      expect(jsonInt(5.9), 5);
      expect(jsonInt(' 7 '), 7);
      expect(jsonInt('abc', 3), 3);
      expect(jsonInt(null), 0);
      expect(jsonDouble('1,5'), 0);
      expect(jsonDouble('1.5'), 1.5);
      expect(jsonDouble(2), 2.0);
    });

    test('строки и логические значения', () {
      expect(jsonString(null, 'x'), 'x');
      expect(jsonString(12), '12');
      expect(jsonBool(true), isTrue);
      expect(jsonBool('true'), isFalse);
    });

    test('связи: строка, запись или список', () {
      expect(jsonRefId('abc'), 'abc');
      expect(jsonRefId({'id': 'z9'}), 'z9');
      expect(jsonRefIds(['a', 'b', '']), ['a', 'b']);
      expect(jsonRefIds('one'), ['one']);
      expect(jsonRefIds(''), isEmpty);
      expect(jsonRefIds(null), isEmpty);
    });

    test('даты PocketBase', () {
      final date = jsonDate('2026-11-02 10:00:00.000Z');

      expect(date, DateTime.utc(2026, 11, 2, 10));
      expect(jsonDate(''), isNull);
      expect(jsonDate(5), isNull);
      expect(jsonDate('вчера'), isNull);
      expect(toPbDate(DateTime.utc(2026, 11, 2, 10)), '2026-11-02 10:00:00.000Z');
    });

    test('вложенные записи из expand', () {
      final json = {
        'expand': {
          'one': {'id': 'a'},
          'many': [
            {'id': 'b'},
            {'id': 'c'},
          ],
        },
      };

      expect(expandedOne(json, 'one'), {'id': 'a'});
      expect(expandedOne(json, 'missing'), isEmpty);
      expect(expandedMany(json, 'many').map((e) => e['id']), ['b', 'c']);
      expect(expandedMany({}, 'many'), isEmpty);
    });
  });

  group('Фильм', () {
    final json = {
      'id': 'm1',
      'title': 'Последний рейс',
      'year': 2025,
      'durationMin': 118,
      'ageRating': '16+',
      'country': 'Россия',
      'poster': 'p.jpg',
      'genres': ['g1', 'g2'],
      'directors': ['p1'],
      'actors': <String>[],
      'expand': {
        'genres': [
          {'id': 'g1', 'title': 'Драма'},
          {'id': 'g2', 'title': 'Триллер'},
        ],
        'directors': [
          {'id': 'p1', 'fullName': 'Алексей Громов'},
        ],
      },
    };

    test('читается вместе со связями и подписями', () {
      final movie = Movie.fromJson(json);

      expect(movie.genreIds, ['g1', 'g2']);
      expect(movie.genreTitles, ['Драма', 'Триллер']);
      expect(movie.directorNames, ['Алексей Громов']);
      expect(movie.actorIds, isEmpty);
      expect(movie.actorNames, isEmpty);
      expect(movie.posterUrl, endsWith('/files/movies/m1/p.jpg?thumb=200x300'));
    });

    test('без постера адреса нет', () {
      expect(Movie.fromJson({'id': 'm2', 'title': 'Без постера'}).posterUrl, isNull);
    });

    test('тело запроса содержит связи и обрезанные строки', () {
      final body = Movie.fromJson({...json, 'title': '  Последний рейс '}).toBody();

      expect(body['title'], 'Последний рейс');
      expect(body['genres'], ['g1', 'g2']);
      expect(body.containsKey('poster'), isFalse);
    });

    test('длительность словами', () {
      expect(formatDuration(45), '45 мин');
      expect(formatDuration(120), '2 ч');
      expect(formatDuration(118), '1 ч 58 мин');
    });
  });

  group('Зал, жанр, персона, профиль', () {
    test('зал считает места', () {
      final hall = Hall.fromJson({
        'id': 'h1',
        'name': 'Зал 1',
        'format': '3D',
        'rows': 8,
        'seatsPerRow': 12,
        'priceFactor': 1.2,
      });

      expect(hall.seats, 96);
      expect(hall.priceFactor, 1.2);
      expect(hall.toBody()['seatsPerRow'], 12);
      expect(Hall.fromJson({'id': 'h'}).priceFactor, 1);
    });

    test('жанр', () {
      final genre = Genre.fromJson({'id': 'g1', 'title': 'Драма'});

      expect(genre.toBody(), {'title': 'Драма'});
    });

    test('персона: пустая дата уходит пустой строкой', () {
      expect(const Person(id: 'p', fullName: ' Иван ').toBody(), {
        'fullName': 'Иван',
        'country': '',
        'birthDate': '',
      });
      final person = Person.fromJson({
        'id': 'p',
        'fullName': 'Иван',
        'birthDate': '1980-05-01 00:00:00.000Z',
      });
      expect(person.birthDate, DateTime.utc(1980, 5, 1));
    });

    test('профиль зрителя', () {
      final profile = ViewerProfile.fromJson({
        'id': 'vp1',
        'user': 'u1',
        'phone': '+7 900 123-45-67',
        'student': true,
        'favoriteGenre': 'g2',
      });

      expect(profile.userId, 'u1');
      expect(profile.student, isTrue);
      expect(profile.toBody()['favoriteGenre'], 'g2');
      expect(profile.toBody()['birthDate'], '');
    });
  });

  group('Сеанс, билет, заказ', () {
    final screeningJson = {
      'id': 's1',
      'movie': 'm1',
      'hall': 'h1',
      'startsAt': '2026-11-05 15:00:00.000Z',
      'endsAt': '2026-11-05 17:18:00.000Z',
      'basePrice': 400,
      'language': 'Дубляж',
      'expand': {
        'movie': {
          'id': 'm1',
          'title': 'Последний рейс',
          'year': 2025,
          'durationMin': 118,
          'ageRating': '16+',
        },
        'hall': {
          'id': 'h1',
          'name': 'Зал 1',
          'format': '2D',
          'rows': 5,
          'seatsPerRow': 8,
          'priceFactor': 1,
        },
      },
    };

    test('сеанс подхватывает фильм и зал из expand', () {
      final screening = Screening.fromJson(screeningJson);

      expect(screening.movieTitle, 'Последний рейс');
      expect(screening.hallName, 'Зал 1');
      expect(screening.endsAt, DateTime.utc(2026, 11, 5, 17, 18));
      expect(screening.toBody()['startsAt'], '2026-11-05 15:00:00.000Z');
      expect(
        screening.toBody().containsKey('endsAt'),
        isFalse,
        reason: 'время окончания считает сервер',
      );
    });

    test('сеанс без expand получает запасные подписи', () {
      final screening = Screening.fromJson({'id': 's2', 'movie': 'm9', 'hall': 'h9'});

      expect(screening.movie, isNull);
      expect(screening.movieTitle, 'Фильм');
      expect(screening.hallName, 'Зал');
    });

    test('билет и его категория', () {
      final ticket = Ticket.fromJson({
        'id': 't1',
        'order': 'o1',
        'screening': 's1',
        'row': 3,
        'seat': 7,
        'category': 'student',
        'price': 280,
        'status': 'used',
        'expand': {'screening': screeningJson},
      });

      expect(ticket.category, TicketCategory.student);
      expect(ticket.status, TicketStatus.used);
      expect(ticket.placeText, 'ряд 3, место 7');
      expect(ticket.screening?.movieTitle, 'Последний рейс');
    });

    test('неизвестные категория и статус заменяются безопасными значениями', () {
      expect(TicketCategory.parse('vip'), TicketCategory.full);
      expect(TicketStatus.parse(null), TicketStatus.sold);
      expect(OrderStatus.parse('что-то'), OrderStatus.paid);
      expect(OrderStatus.parse('refunded'), OrderStatus.refunded);
    });

    test('заказ: канал продажи определяется кассиром', () {
      final online = Order.fromJson({
        'id': 'o1',
        'screening': 's1',
        'customer': 'u1',
        'status': 'paid',
        'total': 400,
      });
      final box = Order.fromJson({
        'id': 'o2',
        'screening': 's1',
        'cashier': 'u2',
        'status': 'paid',
        'total': 800,
      });

      expect(online.isBoxOffice, isFalse);
      expect(box.isBoxOffice, isTrue);
      expect(online.total, 400);
    });
  });

  group('Пользователь и роль', () {
    test('неизвестная роль получает наименьшие права', () {
      final user = AppUser.fromJson({'id': 'u', 'email': 'a@b.c', 'name': '', 'role': 'root'});

      expect(user.role, Role.viewer);
      expect(user.name, 'a@b.c', reason: 'пустое имя заменяется почтой');
    });

    test('профиль для хранилища и обратно', () {
      const user = AppUser(id: 'u1', email: 'admin@atrium.test', name: 'Админ', role: Role.admin);

      final again = AppUser.fromJson(user.toJson().cast<String, dynamic>());

      expect(again.role, Role.admin);
      expect(again.email, user.email);
    });

    test('Role.tryParse', () {
      expect(Role.tryParse('cashier'), Role.cashier);
      expect(Role.tryParse('x'), isNull);
      expect(Role.tryParse(null), isNull);
    });
  });
}
