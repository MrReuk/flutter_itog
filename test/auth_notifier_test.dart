import 'dart:convert';

import 'package:atrium_cinema/auth/app_user.dart';
import 'package:atrium_cinema/auth/auth_api.dart';
import 'package:atrium_cinema/auth/auth_notifier.dart';
import 'package:atrium_cinema/auth/permissions.dart';
import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/auth/session_policy.dart';
import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

String _jwt(DateTime expires) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': expires.millisecondsSinceEpoch ~/ 1000})}.sig';
}

class _ExpiringApi extends FakeAuthApi {
  _ExpiringApi(super.users, this.expiresAt);

  DateTime expiresAt;
  bool offline = false;

  @override
  Future<AuthResult> login(String email, String password) async {
    final base = await super.login(email, password);
    return AuthResult(token: _jwt(expiresAt), user: base.user);
  }

  @override
  Future<AuthResult> refresh(String token) async {
    refreshes++;
    if (offline) throw const NetworkException();
    return AuthResult(token: _jwt(expiresAt.add(const Duration(minutes: 30))), user: users.first);
  }
}

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  final users = TestData().users;
  final t0 = DateTime(2026, 11, 2, 9);

  AuthNotifier make(
    SharedPreferences prefs,
    AuthApi api, {
    DateTime Function()? now,
    SessionPolicy? policy,
  }) {
    return AuthNotifier(
      prefs: prefs,
      api: api,
      now: now ?? () => t0,
      policy: policy ?? const SessionPolicy(),
    );
  }

  group('Вход и выход', () {
    test('успешный вход сохраняет токен, пользователя и роль', () async {
      final prefs = await _prefs();
      final auth = make(prefs, FakeAuthApi(List.of(users)));
      var notified = 0;
      auth.addListener(() => notified++);

      await auth.login('cashier@atrium.test', 'Cashier12345');

      expect(auth.isAuthenticated, isTrue);
      expect(auth.role, Role.cashier);
      expect(auth.accessToken, isNotNull);
      expect(prefs.getString(kAccessKey), auth.accessToken);
      expect(prefs.getString(kUserKey), contains('cashier'));
      expect(prefs.getInt(kStartedKey), t0.millisecondsSinceEpoch);
      expect(notified, greaterThan(0));
    });

    test('неверный пароль не меняет состояние', () async {
      final prefs = await _prefs();
      final auth = make(prefs, FakeAuthApi(List.of(users)));

      await expectLater(
        auth.login('viewer@atrium.test', 'nope'),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(auth.isAuthenticated, isFalse);
      expect(prefs.getString(kAccessKey), isNull);
    });

    test('выход очищает хранилище и запоминает причину', () async {
      final prefs = await _prefs();
      final auth = make(prefs, FakeAuthApi(List.of(users)));
      await auth.login('viewer@atrium.test', 'Viewer12345');

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.accessToken, isNull);
      expect(prefs.getKeys(), isEmpty);
      expect(auth.lastEnd, SessionEnd.manual);

      auth.clearEndNotice();
      expect(auth.lastEnd, isNull);
    });

    test('регистрация сразу входит под новой учётной записью зрителя', () async {
      final prefs = await _prefs();
      final api = FakeAuthApi(List.of(users));
      final auth = make(prefs, api);

      await auth.register(email: 'new@atrium.test', password: 'Pass1234!', name: 'Новый Зритель');

      expect(auth.role, Role.viewer);
      expect(auth.user?.email, 'new@atrium.test');
    });

    test('регистрация с занятой почтой отдаёт ошибку поля и не входит', () async {
      final prefs = await _prefs();
      final auth = make(prefs, FakeAuthApi(List.of(users)));

      await expectLater(
        auth.register(email: 'viewer@atrium.test', password: 'Pass1234!', name: 'Имя'),
        throwsA(
          isA<ValidationException>().having((e) => e.errors.keys, 'fields', contains('email')),
        ),
      );
      expect(auth.isAuthenticated, isFalse);
    });

    test('права проверяются по роли вошедшего', () async {
      final prefs = await _prefs();
      final auth = make(prefs, FakeAuthApi(List.of(users)));
      expect(auth.can(Permission.browse), isFalse);

      await auth.login('admin@atrium.test', 'Admin12345');

      expect(auth.can(Permission.manageUsers), isTrue);
      expect(auth.can(Permission.buyTickets), isFalse);
      expect(auth.has(Role.admin), isTrue);
    });
  });

  group('Сессия переживает перезагрузку страницы', () {
    Future<Map<String, Object>> storedAfterLogin(String email, String password) async {
      final prefs = await _prefs();
      final auth = make(prefs, FakeAuthApi(List.of(users)));
      await auth.login(email, password);
      return {for (final k in prefs.getKeys()) k: prefs.get(k)!};
    }

    test('после перезапуска пользователь восстанавливается без запроса к серверу', () async {
      final stored = await storedAfterLogin('viewer@atrium.test', 'Viewer12345');
      final prefs = await _prefs(stored);
      final api = FakeAuthApi(List.of(users));
      final auth = make(prefs, api, now: () => t0.add(const Duration(minutes: 1)));

      await auth.restore();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.role, Role.viewer);
      expect(api.refreshes, 0);
      expect(auth.isUnverified, isFalse);
    });

    test('без токена остаётся гостем', () async {
      final auth = make(await _prefs(), FakeAuthApi(List.of(users)));

      await auth.restore();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.lastEnd, isNull);
    });

    test('долгое бездействие завершает сессию', () async {
      final stored = await storedAfterLogin('viewer@atrium.test', 'Viewer12345');
      final prefs = await _prefs(stored);
      final auth = make(
        prefs,
        FakeAuthApi(List.of(users)),
        now: () => t0.add(const Duration(hours: 2)),
      );

      await auth.restore();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.lastEnd, SessionEnd.inactivity);
      expect(prefs.getString(kAccessKey), isNull);
    });

    test('предельная длительность сессии важнее активности', () async {
      final stored = await storedAfterLogin('viewer@atrium.test', 'Viewer12345');
      final prefs = await _prefs({
        ...stored,
        kActivityKey: t0.add(const Duration(hours: 8)).millisecondsSinceEpoch,
      });
      final auth = make(
        prefs,
        FakeAuthApi(List.of(users)),
        now: () => t0.add(const Duration(hours: 8, minutes: 1)),
      );

      await auth.restore();

      expect(auth.lastEnd, SessionEnd.maxDuration);
    });

    test('токен отклонён сервером — выход с понятной причиной', () async {
      final prefs = await _prefs({
        kAccessKey: 'fake.token.unknown',
        kStartedKey: t0.millisecondsSinceEpoch,
      });
      final auth = make(
        prefs,
        FakeAuthApi(List.of(users)),
        now: () => t0.add(const Duration(minutes: 1)),
      );

      await auth.restore();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.lastEnd, SessionEnd.tokenRejected);
    });

    test('сервер недоступен: сессия не сбрасывается, но помечена непроверенной', () async {
      final prefs = await _prefs({kAccessKey: 'whatever', kStartedKey: t0.millisecondsSinceEpoch});
      final api = _ExpiringApi(List.of(users), t0.add(const Duration(hours: 1)))..offline = true;
      final auth = make(prefs, api, now: () => t0.add(const Duration(minutes: 1)));

      await auth.restore();

      expect(auth.isUnverified, isTrue);
      expect(auth.accessToken, 'whatever');
      expect(prefs.getString(kAccessKey), 'whatever');
    });

    test(
      'роль берётся из хранилища и подтверждается обновлением токена, если срок близок',
      () async {
        final prefs = await _prefs();
        final api = _ExpiringApi(List.of(users), t0.add(const Duration(seconds: 60)));
        final first = make(prefs, api);
        await first.login('viewer@atrium.test', 'Viewer12345');
        expect(first.needsRefresh, isTrue, reason: 'до конца срока меньше двух минут');

        final second = make(prefs, api, now: () => t0.add(const Duration(seconds: 5)));
        await second.restore();

        expect(api.refreshes, 1);
        expect(second.isAuthenticated, isTrue);
      },
    );
  });

  group('Обновление токена', () {
    test('параллельные вызовы делят один запрос', () async {
      final prefs = await _prefs();
      final api = _ExpiringApi(List.of(users), t0.add(const Duration(seconds: 30)));
      final auth = make(prefs, api);
      await auth.login('viewer@atrium.test', 'Viewer12345');

      await Future.wait([auth.refreshTokens(), auth.refreshTokens(), auth.refreshTokens()]);

      expect(api.refreshes, 1);
      expect(auth.needsRefresh, isFalse);
    });

    test('потеря сессии выходит с причиной «токен отклонён»', () async {
      final auth = make(await _prefs(), FakeAuthApi(List.of(users)));
      await auth.login('viewer@atrium.test', 'Viewer12345');

      await auth.sessionLost();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.lastEnd, SessionEnd.tokenRejected);
    });

    test('обновление без токена — ошибка авторизации', () async {
      final auth = make(await _prefs(), FakeAuthApi(List.of(users)));

      await expectLater(auth.refreshTokens(), throwsA(isA<UnauthorizedException>()));
    });
  });

  group('Активность пользователя', () {
    test('время действия записывается не чаще раза в секунду', () async {
      final prefs = await _prefs();
      var now = t0;
      final auth = make(prefs, FakeAuthApi(List.of(users)), now: () => now);
      await auth.login('viewer@atrium.test', 'Viewer12345');

      now = t0.add(const Duration(milliseconds: 200));
      auth.touch();
      final first = prefs.getInt(kActivityKey);
      now = t0.add(const Duration(milliseconds: 600));
      auth.touch();
      expect(prefs.getInt(kActivityKey), first);

      now = t0.add(const Duration(seconds: 3));
      auth.touch();
      expect(prefs.getInt(kActivityKey), now.millisecondsSinceEpoch);
    });

    test('таймер неактивности выходит с причиной', () async {
      final auth = make(await _prefs(), FakeAuthApi(List.of(users)));
      await auth.login('viewer@atrium.test', 'Viewer12345');

      await auth.expire(SessionEnd.inactivity);

      expect(auth.lastEnd, SessionEnd.inactivity);
      expect(auth.sessionExpiresAt, isNull);
    });

    test('время окончания сессии — начало плюс предельная длительность', () async {
      final auth = make(await _prefs(), FakeAuthApi(List.of(users)));
      await auth.login('viewer@atrium.test', 'Viewer12345');

      expect(auth.sessionExpiresAt, t0.add(const SessionPolicy().maxDuration));
    });
  });

  test('пользователь из хранилища с неверным JSON игнорируется', () async {
    final prefs = await _prefs({
      kAccessKey: 'x',
      kStartedKey: t0.millisecondsSinceEpoch,
      kUserKey: '{не json',
    });
    final api = FakeAuthApi([
      const AppUser(id: 'x', email: 'x@atrium.test', name: 'X', role: Role.viewer),
    ]);
    final auth = make(prefs, api, now: () => t0.add(const Duration(seconds: 1)));

    await auth.restore();

    expect(api.refreshes, 1, reason: 'профиля нет, поэтому спрашиваем сервер');
  });
}
