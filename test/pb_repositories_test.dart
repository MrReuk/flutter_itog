import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:atrium_cinema/models/genre.dart';
import 'package:atrium_cinema/models/list_query.dart';
import 'package:atrium_cinema/models/list_specs.dart';
import 'package:atrium_cinema/models/ticket.dart';
import 'package:atrium_cinema/repositories/pb_repository.dart';
import 'package:atrium_cinema/repositories/repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_adapter.dart';

ListQuery _q(ListSpec spec, Map<String, String> params) => ListQuery.fromParams(spec, params);

final DateTime _clock = DateTime.utc(2026, 11, 2, 10);

Map<String, Object?> _genre(int i) => {'id': 'g$i', 'title': 'Жанр $i'};

void main() {
  group('Запросы списков: поиск, фильтры, сортировка и страница уходят на сервер', () {
    test('фильмы: все условия попадают в filter, сортировка и страница в параметры', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, pbPage([], total: 0)));
      final repo = PbMovieRepository(dio: dioFor(adapter));

      await repo.find(
        _q(kMovieSpec, {
          'search': "it's",
          'genre': 'g3',
          'age': '16+',
          'yearFrom': '2020',
          'yearTo': '2025',
          'sort': 'year,desc',
          'page': '2',
          'size': '25',
        }),
      );

      final request = adapter.requests.single;
      expect(request.path, '/collections/movies/records');
      expect(request.queryParameters['page'], 2);
      expect(request.queryParameters['perPage'], 25);
      expect(request.queryParameters['sort'], '-year');
      expect(request.queryParameters['expand'], 'genres,directors,actors');
      expect(
        request.queryParameters['filter'],
        "(title ~ 'it\\'s' || country ~ 'it\\'s') && (genres ?= 'g3') && (ageRating = '16+') "
        '&& (year >= 2020) && (year <= 2025)',
      );
    });

    test('без условий фильтра нет вовсе, сортировка по возрастанию', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, pbPage([])));
      final repo = PbMovieRepository(dio: dioFor(adapter));

      await repo.find(ListQuery.initial(kMovieSpec));

      final params = adapter.requests.single.queryParameters;
      expect(params.containsKey('filter'), isFalse);
      expect(params['sort'], 'title');
      expect(params['page'], 1);
      expect(params['perPage'], 10);
    });

    test(
      'сеансы: по умолчанию только предстоящие, дата переводится в границы суток по Москве',
      () async {
        final adapter = FakeAdapter((_) => FakeReply(200, pbPage([])));
        final repo = PbScreeningRepository(dio: dioFor(adapter), now: () => _clock);

        await repo.find(
          _q(kScreeningSpec, {
            'movie': 'm1',
            'hall': 'h2',
            'language': 'Дубляж',
            'date': '2026-11-05',
            'sort': 'movie',
          }),
        );

        final params = adapter.requests.single.queryParameters;
        expect(params['sort'], 'movie.title');
        expect(params['expand'], 'movie,hall');
        expect(
          params['filter'],
          "(movie = 'm1') && (hall = 'h2') && (language = 'Дубляж') "
          "&& (startsAt >= '2026-11-02 10:00:00.000Z') "
          "&& (startsAt >= '2026-11-04 21:00:00.000Z' && startsAt < '2026-11-05 21:00:00.000Z')",
        );
      },
    );

    test('сеансы: период «прошедшие» и «все»', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, pbPage([])));
      final repo = PbScreeningRepository(dio: dioFor(adapter), now: () => _clock);

      await repo.find(_q(kScreeningSpec, {'period': 'past'}));
      await repo.find(_q(kScreeningSpec, {'period': 'all'}));

      expect(
        adapter.requests[0].queryParameters['filter'],
        "(startsAt < '2026-11-02 10:00:00.000Z')",
      );
      expect(adapter.requests[1].queryParameters.containsKey('filter'), isFalse);
    });

    test('заказы: канал продажи, дата, поиск по покупателю, новые сверху', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, pbPage([])));
      final repo = PbOrderRepository(dio: dioFor(adapter));

      await repo.find(
        _q(kOrderSpec, {
          'channel': 'box',
          'status': 'paid',
          'date': '2026-11-05',
          'search': 'иван',
        }),
      );
      await repo.find(_q(kOrderSpec, {'channel': 'online'}));

      final first = adapter.requests[0].queryParameters;
      expect(first['sort'], '-created');
      expect(first['expand'], 'screening.movie,screening.hall,customer');
      expect(
        first['filter'],
        "(customer.name ~ 'иван' || customer.email ~ 'иван' || id = 'иван') && (status = 'paid') "
        "&& (cashier != '') && (created >= '2026-11-04 21:00:00.000Z' && created < '2026-11-05 21:00:00.000Z')",
      );
      expect(adapter.requests[1].queryParameters['filter'], "(cashier = '')");
    });

    test('билеты: сортировка по времени сеанса и период через связь', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, pbPage([])));
      final repo = PbTicketRepository(dio: dioFor(adapter), now: () => _clock);

      await repo.find(
        _q(kTicketSpec, {
          'status': 'sold',
          'category': 'child',
          'period': 'past',
          'sort': 'screening,asc',
        }),
      );

      final params = adapter.requests.single.queryParameters;
      expect(params['sort'], 'screening.startsAt');
      expect(
        params['filter'],
        "(status = 'sold') && (category = 'child') && (screening.startsAt < '2026-11-02 10:00:00.000Z')",
      );
    });

    test('справочники: жанры, персоны, залы, пользователи', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, pbPage([])));
      final dio = dioFor(adapter);

      await PbGenreRepository(dio: dio).find(_q(kGenreSpec, {'search': 'дра'}));
      await PbPersonRepository(
        dio: dio,
      ).find(_q(kPersonSpec, {'search': 'ив', 'country': 'Россия'}));
      await PbHallRepository(
        dio: dio,
      ).find(_q(kHallSpec, {'format': 'IMAX', 'sort': 'priceFactor,desc'}));
      await PbUserRepository(dio: dio).find(_q(kUserSpec, {'role': 'cashier', 'search': 'мар'}));

      expect(adapter.requests[0].queryParameters['filter'], "(title ~ 'дра')");
      expect(
        adapter.requests[1].queryParameters['filter'],
        "(fullName ~ 'ив') && (country = 'Россия')",
      );
      expect(adapter.requests[2].queryParameters['filter'], "(format = 'IMAX')");
      expect(adapter.requests[2].queryParameters['sort'], '-priceFactor');
      expect(
        adapter.requests[3].queryParameters['filter'],
        "(name ~ 'мар' || email ~ 'мар') && (role = 'cashier')",
      );
    });

    test('кавычки и обратная косая черта в значениях не ломают фильтр', () {
      expect(pbQuote("О'Брайен"), "'О\\'Брайен'");
      expect(pbQuote(r'a\b'), "'ab'");
      expect(pbQuote("' || 1=1 || '"), "'\\' || 1=1 || \\''");
    });

    test('FilterBuilder пропускает пустые значения', () {
      final filter = FilterBuilder()
        ..addIf('  ', (q) => 'a = $q')
        ..addIf('x', (q) => 'b = $q')
        ..add('c > 1');

      expect(filter.build(), "(b = 'x') && (c > 1)");
    });
  });

  group('Ответы сервера', () {
    test('страница разбирается вместе с общим числом записей', () async {
      final adapter = FakeAdapter(
        (_) => FakeReply(200, pbPage([_genre(1), _genre(2)], total: 23, page: 2, perPage: 10)),
      );
      final repo = PbGenreRepository(dio: dioFor(adapter));

      final result = await repo.find(ListQuery.initial(kGenreSpec));

      expect(result.items.map((g) => g.title), ['Жанр 1', 'Жанр 2']);
      expect(result.total, 23);
      expect(result.page, 2);
      expect(result.totalPages, 3);
      expect(result.hasNext, isTrue);
    });

    test('ответ без списка items — ошибка сервера, а не падение', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {'oops': true}));
      final repo = PbGenreRepository(dio: dioFor(adapter));

      await expectLater(repo.find(ListQuery.initial(kGenreSpec)), throwsA(isA<ServerException>()));
    });

    test('недоступный сервер даёт NetworkException', () async {
      final adapter = FakeAdapter((o) => throw offline(o));
      final repo = PbGenreRepository(dio: dioFor(adapter));

      await expectLater(repo.find(ListQuery.initial(kGenreSpec)), throwsA(isA<NetworkException>()));
    });

    test('ошибка 500 превращается в ServerException', () async {
      final adapter = FakeAdapter((_) => const FakeReply(500, {'message': 'boom'}));
      final repo = PbGenreRepository(dio: dioFor(adapter));

      await expectLater(repo.findAll(), throwsA(isA<ServerException>()));
    });
  });

  group('Справочники целиком', () {
    FakeAdapter paged(int total) {
      return FakeAdapter((options) {
        final page = options.queryParameters['page'] as int;
        final from = (page - 1) * 200;
        final to = from + 200 > total ? total : from + 200;
        return FakeReply(
          200,
          pbPage(
            [for (var i = from; i < to; i++) _genre(i)],
            total: total,
            perPage: 200,
            page: page,
          ),
        );
      });
    }

    test('читаются постранично, пока не кончатся', () async {
      final adapter = paged(450);
      final repo = PbGenreRepository(dio: dioFor(adapter));

      final all = await repo.findAll();

      expect(all, hasLength(450));
      expect(adapter.requests, hasLength(3));
      expect(adapter.requests.first.queryParameters['sort'], 'title');
    });

    test('результат кэшируется на пять минут', () async {
      final adapter = paged(5);
      var now = _clock;
      final repo = PbGenreRepository(dio: dioFor(adapter), now: () => now);

      await repo.findAll();
      await repo.findAll();
      expect(adapter.requests, hasLength(1));

      now = now.add(const Duration(minutes: 4));
      await repo.findAll();
      expect(adapter.requests, hasLength(1));

      now = now.add(const Duration(minutes: 2));
      await repo.findAll();
      expect(adapter.requests, hasLength(2));
    });

    test('изменение данных сбрасывает кэш', () async {
      final adapter = FakeAdapter((o) {
        if (o.method == 'POST') {
          return const FakeReply(200, {'id': 'g9', 'title': 'Новый'});
        }
        return FakeReply(200, pbPage([_genre(1)]));
      });
      final repo = PbGenreRepository(dio: dioFor(adapter), now: () => _clock);

      await repo.findAll();
      await repo.create(const Genre(id: '', title: 'Новый'));
      await repo.findAll();

      expect(adapter.calls, [
        'GET /collections/genres/records',
        'POST /collections/genres/records',
        'GET /collections/genres/records',
      ]);
    });

    test('неудачная загрузка не остаётся в кэше', () async {
      var fail = true;
      final adapter = FakeAdapter((o) {
        if (fail) throw offline(o);
        return FakeReply(200, pbPage([_genre(1)]));
      });
      final repo = PbGenreRepository(dio: dioFor(adapter), now: () => _clock);

      await expectLater(repo.findAll(), throwsA(isA<NetworkException>()));
      fail = false;

      expect(await repo.findAll(), hasLength(1));
    });
  });

  group('Создание, изменение, удаление', () {
    test('создание отправляет обрезанные данные и возвращает запись сервера', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {'id': 'g9', 'title': 'Драма'}));
      final repo = PbGenreRepository(dio: dioFor(adapter));

      final created = await repo.create(const Genre(id: '', title: '  Драма '));

      expect(created.id, 'g9');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {'title': 'Драма'});
    });

    test('ошибка проверки приходит с сообщениями по полям', () async {
      final adapter = FakeAdapter(
        (_) => FakeReply(400, pbValidation({'title': 'Value must be unique.'})),
      );
      final repo = PbGenreRepository(dio: dioFor(adapter));

      await expectLater(
        repo.create(const Genre(id: '', title: 'Драма')),
        throwsA(
          isA<ValidationException>().having((e) => e.errors, 'errors', {
            'title': 'Value must be unique.',
          }),
        ),
      );
    });

    test('изменение — PATCH по идентификатору', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {'id': 'g1', 'title': 'Комедия'}));
      final repo = PbGenreRepository(dio: dioFor(adapter));

      await repo.update(const Genre(id: 'g1', title: 'Комедия'));

      expect(adapter.calls, ['PATCH /collections/genres/records/g1']);
    });

    test('запись, которой нет, читается как null', () async {
      final adapter = FakeAdapter((_) => const FakeReply(404, {'message': 'not found'}));
      final repo = PbGenreRepository(dio: dioFor(adapter));

      expect(await repo.findById('nope'), isNull);
    });

    test('удаление записи со связями — понятный конфликт', () async {
      final adapter = FakeAdapter(
        (_) => const FakeReply(400, {
          'status': 400,
          'message':
              'Failed to delete record. Make sure that the record is not part of a required relation reference.',
          'data': {},
        }),
      );
      final repo = PbHallRepository(dio: dioFor(adapter));

      await expectLater(
        repo.delete('h1'),
        throwsA(
          isA<ConflictException>().having((e) => e.message, 'message', contains('используется')),
        ),
      );
    });

    test('групповое удаление считает, сколько записей удалено', () async {
      final adapter = FakeAdapter((o) {
        if (o.path.endsWith('/a')) {
          return const FakeReply(400, {'message': 'Failed to delete record.', 'data': {}});
        }
        return const FakeReply(204);
      });
      final repo = PbHallRepository(dio: dioFor(adapter));

      expect(await repo.deleteMany(['a', 'b', 'c']), 2);
      await expectLater(repo.deleteMany(['a']), throwsA(isA<ConflictException>()));
    });

    test('при потере связи групповое удаление прерывается', () async {
      final adapter = FakeAdapter((o) => throw offline(o));
      final repo = PbHallRepository(dio: dioFor(adapter));

      await expectLater(repo.deleteMany(['a', 'b']), throwsA(isA<NetworkException>()));
      expect(adapter.requests, hasLength(1));
    });
  });

  group('Покупка билетов', () {
    Map<String, Object?> ticketJson(String id, int row, int seat) => {
      'id': id,
      'order': 'o9',
      'screening': 's1',
      'row': row,
      'seat': seat,
      'category': 'full',
      'price': 400,
      'status': 'sold',
    };

    final orderJson = {
      'id': 'o9',
      'screening': 's1',
      'customer': 'u1',
      'status': 'paid',
      'total': 800,
    };

    FakeReply route(RequestOptions o) {
      if (o.method == 'POST' && o.path == '/collections/orders/records') {
        return const FakeReply(200, {'id': 'o9'});
      }
      if (o.method == 'POST' && o.path == '/collections/tickets/records') {
        final data = o.data as Map;
        final row = data['row'] as int;
        final seat = data['seat'] as int;
        return FakeReply(200, ticketJson('t$row$seat', row, seat));
      }
      if (o.method == 'GET' && o.path == '/collections/orders/records/o9') {
        return FakeReply(200, orderJson);
      }
      return const FakeReply(200, {});
    }

    test('заказ и билеты создаются по очереди, итог читается с сервера', () async {
      final adapter = FakeAdapter(route);
      final repo = PbOrderRepository(dio: dioFor(adapter));

      final result = await repo.checkout(
        screeningId: 's1',
        customerId: 'u1',
        seats: [
          (row: 2, seat: 3, category: TicketCategory.full),
          (row: 2, seat: 4, category: TicketCategory.child),
        ],
      );

      expect(adapter.calls, [
        'POST /collections/orders/records',
        'POST /collections/tickets/records',
        'POST /collections/tickets/records',
        'GET /collections/orders/records/o9',
      ]);
      expect(adapter.requests[0].data, {'screening': 's1', 'customer': 'u1', 'status': 'paid'});
      expect(adapter.requests[2].data, {
        'order': 'o9',
        'screening': 's1',
        'row': 2,
        'seat': 4,
        'category': 'child',
        'status': 'sold',
      });
      expect(result.order.total, 800);
      expect(result.tickets, hasLength(2));
    });

    test('на кассе покупатель не указывается', () async {
      final adapter = FakeAdapter(route);
      final repo = PbOrderRepository(dio: dioFor(adapter));

      await repo.checkout(
        screeningId: 's1',
        seats: [(row: 1, seat: 1, category: TicketCategory.full)],
      );

      expect(adapter.requests.first.data, {'screening': 's1', 'status': 'paid'});
    });

    test('без мест заказ не создаётся', () async {
      final adapter = FakeAdapter(route);
      final repo = PbOrderRepository(dio: dioFor(adapter));

      await expectLater(
        repo.checkout(screeningId: 's1', seats: const []),
        throwsA(isA<ValidationException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'занятое место: купленные билеты возвращаются, заказ закрывается, ошибка сохраняется',
      () async {
        var tickets = 0;
        final adapter = FakeAdapter((o) {
          if (o.method == 'POST' && o.path == '/collections/tickets/records') {
            tickets++;
            if (tickets == 2) {
              return FakeReply(
                409,
                pbValidation({'seat': 'Это место уже куплено.'}, message: 'Место уже занято'),
              );
            }
            return FakeReply(200, ticketJson('t1', 2, 3));
          }
          return route(o);
        });
        final repo = PbOrderRepository(dio: dioFor(adapter));

        await expectLater(
          repo.checkout(
            screeningId: 's1',
            customerId: 'u1',
            seats: [
              (row: 2, seat: 3, category: TicketCategory.full),
              (row: 2, seat: 4, category: TicketCategory.full),
            ],
          ),
          throwsA(
            isA<ConflictException>().having(
              (e) => e.errors['seat'],
              'seat',
              'Это место уже куплено.',
            ),
          ),
        );

        expect(adapter.calls.skip(3), [
          'PATCH /collections/tickets/records/t1',
          'PATCH /collections/orders/records/o9',
        ]);
        expect(adapter.requests[3].data, {'status': 'returned'});
        expect(adapter.requests[4].data, {'status': 'refunded'});
      },
    );

    test('возврат заказа: действующие билеты возвращаются, заказ закрывается', () async {
      final adapter = FakeAdapter((o) {
        if (o.method == 'GET') {
          return FakeReply(
            200,
            pbPage([
              ticketJson('t1', 1, 1),
              {...ticketJson('t2', 1, 2), 'status': 'returned'},
              ticketJson('t3', 1, 3),
            ]),
          );
        }
        return const FakeReply(200, {});
      });
      final repo = PbOrderRepository(dio: dioFor(adapter));

      await repo.refund('o9');

      expect(adapter.calls, [
        'GET /collections/tickets/records',
        'PATCH /collections/tickets/records/t1',
        'PATCH /collections/tickets/records/t3',
        'PATCH /collections/orders/records/o9',
      ]);
      expect(adapter.requests.first.queryParameters['filter'], "order = 'o9'");
    });

    test('в заказе с использованным билетом возврат запрещён', () async {
      final adapter = FakeAdapter((o) {
        return FakeReply(
          200,
          pbPage([
            ticketJson('t1', 1, 1),
            {...ticketJson('t2', 1, 2), 'status': 'used'},
          ]),
        );
      });
      final repo = PbOrderRepository(dio: dioFor(adapter));

      await expectLater(repo.refund('o9'), throwsA(isA<ConflictException>()));
      expect(adapter.calls, ['GET /collections/tickets/records']);
    });

    test('занятые места сеанса читаются из служебного маршрута', () async {
      final adapter = FakeAdapter(
        (_) => const FakeReply(200, [
          {'row': 1, 'seat': 2},
          {'row': 3, 'seat': 4},
        ]),
      );
      final repo = PbScreeningRepository(dio: dioFor(adapter));

      final seats = await repo.takenSeats('s1');

      expect(adapter.requests.single.path, '/atrium/taken/s1');
      expect(seats, [(row: 1, seat: 2), (row: 3, seat: 4)]);
    });

    test('смена статуса билета — PATCH только поля status', () async {
      final adapter = FakeAdapter(
        (_) => FakeReply(200, ticketJson('t1', 1, 1)..['status'] = 'used'),
      );
      final repo = PbTicketRepository(dio: dioFor(adapter));

      final ticket = await repo.setStatus('t1', TicketStatus.used);

      expect(adapter.requests.single.data, {'status': 'used'});
      expect(ticket.status, TicketStatus.used);
    });
  });

  group('Пользователи и профиль', () {
    test('администратор создаёт пользователя с ролью', () async {
      final adapter = FakeAdapter(
        (_) => const FakeReply(200, {
          'id': 'u9',
          'email': 'new@atrium.test',
          'name': 'Новый',
          'role': 'cashier',
        }),
      );
      final repo = PbUserRepository(dio: dioFor(adapter));

      final user = await repo.createUser(
        email: ' new@atrium.test ',
        name: ' Новый ',
        role: Role.cashier,
        password: 'Pass1234!',
      );

      expect(user.role, Role.cashier);
      final body = adapter.requests.single.data as Map;
      expect(body['email'], 'new@atrium.test');
      expect(body['role'], 'cashier');
      expect(body['passwordConfirm'], 'Pass1234!');
    });

    test('профиль зрителя: поиск по пользователю и сохранение', () async {
      final adapter = FakeAdapter((o) {
        if (o.method == 'GET') {
          return FakeReply(
            200,
            pbPage([
              {'id': 'vp1', 'user': 'u1', 'phone': '+7 900 123-45-67'},
            ]),
          );
        }
        return const FakeReply(200, {'id': 'vp1', 'user': 'u1', 'phone': '+7 900 000-00-00'});
      });
      final repo = PbProfileRepository(dio: dioFor(adapter));

      final profile = await repo.forUser("u'1");
      expect(adapter.requests.single.queryParameters['filter'], "user = 'u\\'1'");
      expect(profile?.phone, '+7 900 123-45-67');

      final saved = await repo.save(profile!);
      expect(saved.phone, '+7 900 000-00-00');
      expect(
        adapter.last('PATCH', '/collections/viewer_profiles/records/vp1').data,
        containsPair('student', false),
      );
    });

    test('у пользователя ещё нет профиля', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, pbPage([])));

      expect(await PbProfileRepository(dio: dioFor(adapter)).forUser('u1'), isNull);
    });
  });
}
