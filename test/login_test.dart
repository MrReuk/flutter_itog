import 'package:atrium_cinema/auth/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  Future<void> fillAndSubmit(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const ValueKey('login-email')), email);
    await tester.enterText(find.byKey(const ValueKey('login-password')), password);
    await tapKey(tester, 'login-submit');
  }

  testWidgets('гость видит форму входа', (tester) async {
    final world = await makeWorld(tester, role: null);

    await pumpAtrium(tester, world, location: '/login');

    expect(find.text('Вход в систему'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
  });

  testWidgets('пустая форма: ошибки показываются у полей, запрос не отправляется', (tester) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/login');

    await tapKey(tester, 'login-submit');

    expect(find.text('Введите почту'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
    expect(world.auth.isAuthenticated, isFalse);
  });

  testWidgets('неверный пароль: сообщение об ошибке, вход не выполнен', (tester) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/login');

    await fillAndSubmit(tester, 'viewer@atrium.test', 'неверный');

    expect(find.text('Неверная почта или пароль.'), findsOneWidget);
    expect(world.auth.isAuthenticated, isFalse);
    expect(find.text('Вход в систему'), findsOneWidget);
  });

  testWidgets('зритель входит и попадает на афишу', (tester) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/login');

    await fillAndSubmit(tester, 'viewer@atrium.test', 'Viewer12345');

    expect(world.auth.role, Role.viewer);
    expect(find.text('Последний рейс'), findsOneWidget);
    expect(currentLocation(tester), '/');
  });

  testWidgets('гость на закрытом адресе: после входа возвращается туда, куда шёл', (tester) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/orders');

    expect(find.text('Вход в систему'), findsOneWidget);

    await fillAndSubmit(tester, 'cashier@atrium.test', 'Cashier12345');

    expect(currentLocation(tester), '/orders');
    expect(find.text('Заказы'), findsWidgets);
  });

  testWidgets('пароль можно показать и скрыть', (tester) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/login');

    await tapTooltip(tester, 'Показать пароль');

    expect(find.byTooltip('Скрыть пароль'), findsOneWidget);
  });

  testWidgets('выход из системы возвращает на экран входа', (tester) async {
    final world = await makeWorld(tester, role: Role.viewer);
    await pumpAtrium(tester, world);

    await tapKey(tester, 'user-menu');
    await tapText(tester, 'Выйти');

    expect(world.auth.isAuthenticated, isFalse);
    expect(find.text('Вход в систему'), findsOneWidget);
    expect(find.text('Вы вышли из системы.'), findsOneWidget);
  });

  testWidgets('регистрация создаёт зрителя и сразу входит', (tester) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/register');

    await tester.enterText(find.byKey(const ValueKey('register-name')), 'Пётр Новиков');
    await tester.enterText(find.byKey(const ValueKey('register-email')), 'petr@atrium.test');
    await tester.enterText(find.byKey(const ValueKey('register-password')), 'Abcdef1!');
    await tester.enterText(find.byKey(const ValueKey('register-repeat')), 'Abcdef1!');
    await tapKey(tester, 'register-submit');

    expect(world.auth.role, Role.viewer);
    expect(world.auth.user?.email, 'petr@atrium.test');
  });

  testWidgets('регистрация: слабый пароль и несовпадение паролей показываются у полей', (
    tester,
  ) async {
    final world = await makeWorld(tester, role: null);
    await pumpAtrium(tester, world, location: '/register');

    await tester.enterText(find.byKey(const ValueKey('register-name')), 'Пётр');
    await tester.enterText(find.byKey(const ValueKey('register-email')), 'не-почта');
    await tester.enterText(find.byKey(const ValueKey('register-password')), 'abc');
    await tester.enterText(find.byKey(const ValueKey('register-repeat')), 'abd');
    await tapKey(tester, 'register-submit');

    expect(find.text('Введите адрес в формате name@example.com'), findsOneWidget);
    expect(find.textContaining('Пароль не короче 8'), findsOneWidget);
    expect(find.text('Пароли не совпадают'), findsOneWidget);
    expect(world.auth.isAuthenticated, isFalse);
  });
}
