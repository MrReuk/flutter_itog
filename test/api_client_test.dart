import 'package:atrium_cinema/auth/auth_api.dart';
import 'package:atrium_cinema/core/api_client.dart';
import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:atrium_cinema/core/auth_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_adapter.dart';

class FakeGateway implements AuthGateway {
  String? token = 'old';
  bool needs = false;
  int refreshes = 0;
  int lost = 0;
  Object? refreshError;

  @override
  String? get accessToken => token;

  @override
  bool get needsRefresh => needs;

  @override
  Future<void> refreshTokens() async {
    refreshes++;
    final error = refreshError;
    if (error != null) throw error;
    token = 'new';
    needs = false;
  }

  @override
  Future<void> sessionLost() async {
    lost++;
    token = null;
  }
}

void main() {
  group('Токен в запросах', () {
    test('в заголовок кладётся «сырой» токен без слова Bearer', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {'ok': true}));
      final dio = dioFor(adapter, auth: FakeGateway());

      await dio.get<dynamic>('/collections/movies/records');

      expect(adapter.requests.single.headers['Authorization'], 'old');
    });

    test('запросы входа идут без токена', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {'token': 't', 'record': {}}));
      final dio = dioFor(adapter, auth: FakeGateway());

      await dio.post<dynamic>(
        '/collections/users/auth-with-password',
        data: {'identity': 'a', 'password': 'b'},
      );

      expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('без входа заголовка нет', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {}));
      final gateway = FakeGateway()..token = null;

      await dioFor(adapter, auth: gateway).get<dynamic>('/collections/movies/records');

      expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('токен, срок которого подходит к концу, обновляется до запроса', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {}));
      final gateway = FakeGateway()..needs = true;

      await dioFor(adapter, auth: gateway).get<dynamic>('/collections/movies/records');

      expect(gateway.refreshes, 1);
      expect(adapter.requests.single.headers['Authorization'], 'new');
    });

    test('если обновить токен нельзя, запрос не уходит и сессия закрывается', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {}));
      final gateway = FakeGateway()
        ..needs = true
        ..refreshError = const UnauthorizedException();

      await expectLater(
        dioFor(adapter, auth: gateway).get<dynamic>('/collections/movies/records'),
        throwsA(isA<DioException>().having((e) => e.error, 'error', isA<UnauthorizedException>())),
      );

      expect(gateway.lost, 1);
      expect(adapter.requests, isEmpty);
    });

    test('сервер недоступен при обновлении: запрос уходит со старым токеном', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {}));
      final gateway = FakeGateway()
        ..needs = true
        ..refreshError = const NetworkException();

      await dioFor(adapter, auth: gateway).get<dynamic>('/collections/movies/records');

      expect(adapter.requests.single.headers['Authorization'], 'old');
      expect(gateway.lost, 0);
    });
  });

  group('Ответ 401', () {
    test('токен обновляется, запрос повторяется с новым токеном', () async {
      final adapter = FakeAdapter((o) {
        return o.headers['Authorization'] == 'old'
            ? const FakeReply(401, {'message': 'expired'})
            : const FakeReply(200, {'ok': true});
      });
      final gateway = FakeGateway();

      final response = await dioFor(
        adapter,
        auth: gateway,
      ).get<dynamic>('/collections/movies/records');

      expect(response.statusCode, 200);
      expect(gateway.refreshes, 1);
      expect(adapter.sentHeaders.map((h) => h['Authorization']), ['old', 'new']);
    });

    test('повторный 401 не зацикливается: сессия закрывается', () async {
      final adapter = FakeAdapter((_) => const FakeReply(401, {'message': 'no'}));
      final gateway = FakeGateway();

      await expectLater(
        dioFor(adapter, auth: gateway).get<dynamic>('/collections/movies/records'),
        throwsA(isA<DioException>().having((e) => e.error, 'error', isA<UnauthorizedException>())),
      );

      expect(gateway.refreshes, 1);
      expect(gateway.lost, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('если сервер не отвечает при обновлении, сессию не рвём', () async {
      final adapter = FakeAdapter((_) => const FakeReply(401, {'message': 'expired'}));
      final gateway = FakeGateway()..refreshError = const NetworkException();

      await expectLater(
        dioFor(adapter, auth: gateway).get<dynamic>('/collections/movies/records'),
        throwsA(isA<DioException>().having((e) => e.error, 'error', isA<NetworkException>())),
      );

      expect(gateway.lost, 0);
    });

    test('401 на запросе входа обрабатывается самим экраном и не вызывает обновление', () async {
      final adapter = FakeAdapter((_) => const FakeReply(401, {'message': 'bad'}));
      final gateway = FakeGateway();

      await expectLater(
        dioFor(adapter, auth: gateway).post<dynamic>('/collections/users/auth-with-password'),
        throwsA(isA<DioException>()),
      );

      expect(gateway.refreshes, 0);
    });
  });

  group('Повторы при сбое сети', () {
    const delays = [Duration.zero, Duration.zero];

    test('чтение повторяется до двух раз', () async {
      var fails = 2;
      final adapter = FakeAdapter((o) {
        if (fails-- > 0) throw offline(o);
        return const FakeReply(200, {'ok': true});
      });

      final response = await dioFor(
        adapter,
        retryDelays: delays,
      ).get<dynamic>('/collections/genres/records');

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(3));
    });

    test('после трёх неудач приходит понятная ошибка', () async {
      final adapter = FakeAdapter((o) => throw offline(o));
      final dio = dioFor(adapter, retryDelays: delays);

      await expectLater(
        dio.get<dynamic>('/collections/genres/records'),
        throwsA(
          isA<DioException>().having((e) => mapDioError(e), 'mapped', isA<NetworkException>()),
        ),
      );

      expect(adapter.requests, hasLength(3));
    });

    test('запись не повторяется: иначе билет мог бы продаться дважды', () async {
      final adapter = FakeAdapter((o) => throw offline(o));
      final dio = dioFor(adapter, retryDelays: delays);

      await expectLater(
        dio.post<dynamic>('/collections/tickets/records', data: {}),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, hasLength(1));
    });
  });

  group('Запросы входа', () {
    AuthApi apiWith(FakeAdapter adapter) =>
        AuthApi(buildAuthDio(baseUrl: 'http://pb.test/api', adapter: adapter));

    final authReply = {
      'token': 'jwt.token.value',
      'record': {'id': 'u1', 'email': 'viewer@atrium.test', 'name': 'Иван', 'role': 'viewer'},
    };

    test('успешный вход возвращает токен и пользователя с ролью', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, authReply));

      final result = await apiWith(adapter).login(' viewer@atrium.test ', 'Viewer12345');

      expect(result.token, 'jwt.token.value');
      expect(result.user.role.code, 'viewer');
      expect(adapter.requests.single.path, '/collections/users/auth-with-password');
      expect(adapter.requests.single.data, {
        'identity': 'viewer@atrium.test',
        'password': 'Viewer12345',
      });
    });

    test('неверный пароль (PocketBase отвечает 400) — понятное сообщение', () async {
      final adapter = FakeAdapter(
        (_) => const FakeReply(400, {'message': 'Failed to authenticate.', 'data': {}}),
      );

      await expectLater(
        apiWith(adapter).login('viewer@atrium.test', 'wrong'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Неверная почта или пароль.',
          ),
        ),
      );
    });

    test('ответ без токена — ошибка сервера', () async {
      final adapter = FakeAdapter((_) => const FakeReply(200, {'record': {}}));

      await expectLater(apiWith(adapter).login('a@b.cc', 'x'), throwsA(isA<ServerException>()));
    });

    test('обновление токена: сырой токен в заголовке', () async {
      final adapter = FakeAdapter((_) => FakeReply(200, authReply));

      await apiWith(adapter).refresh('old.token.value');

      expect(adapter.requests.single.path, '/collections/users/auth-refresh');
      expect(adapter.requests.single.headers['Authorization'], 'old.token.value');
    });

    test('отклонённый токен при обновлении — требуется вход', () async {
      final adapter = FakeAdapter((_) => const FakeReply(401, {'message': 'invalid'}));

      await expectLater(apiWith(adapter).refresh('bad'), throwsA(isA<UnauthorizedException>()));
    });

    test('регистрация всегда создаёт зрителя', () async {
      final adapter = FakeAdapter(
        (_) => const FakeReply(200, {
          'id': 'u9',
          'email': 'new@atrium.test',
          'name': 'Новый',
          'role': 'viewer',
        }),
      );

      final user = await apiWith(
        adapter,
      ).register(email: 'new@atrium.test', password: 'Pass1234!', name: ' Новый ');

      expect(user.id, 'u9');
      final body = adapter.requests.single.data as Map;
      expect(body['role'], 'viewer');
      expect(body['name'], 'Новый');
      expect(body['passwordConfirm'], 'Pass1234!');
    });

    test('занятая почта приходит ошибкой поля', () async {
      final adapter = FakeAdapter(
        (_) => FakeReply(400, pbValidation({'email': 'Value must be unique.'})),
      );

      await expectLater(
        apiWith(adapter).register(email: 'a@b.cc', password: 'Pass1234!', name: 'Имя'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['email'],
            'email',
            'Value must be unique.',
          ),
        ),
      );
    });
  });
}
