import 'package:atrium_cinema/app.dart';
import 'package:atrium_cinema/auth/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';

void setScreen(WidgetTester tester, {double width = 1280, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<TestWorld> makeWorld(WidgetTester tester, {Role? role = Role.admin}) async {
  late TestWorld world;
  await tester.runAsync(() async {
    world = await TestWorld.create(role: role);
  });
  return world;
}

Future<void> pumpAtrium(
  WidgetTester tester,
  TestWorld world, {
  String location = '/',
  double width = 1280,
  double height = 900,
}) async {
  setScreen(tester, width: width, height: height);
  await tester.pumpWidget(AtriumApp(repositories: world.repos, initialLocation: location));
  await tester.pumpAndSettle();
}

Future<void> tapTooltip(WidgetTester tester, String message) async {
  await tester.tap(find.byTooltip(message).first);
  await tester.pumpAndSettle();
}

Future<void> enterField(WidgetTester tester, String label, String text) async {
  final plain = find.widgetWithText(TextFormField, label);
  final field = plain.evaluate().isNotEmpty
      ? plain
      : find.widgetWithText(TextFormField, '$label *');
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

int dataRowCount(WidgetTester tester) =>
    tester.widget<DataTable>(find.byType(DataTable)).rows.length;

Future<void> tapLast(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> pickOption(WidgetTester tester, String label, String option) async {
  final plain = find.text(label);
  final field = (plain.evaluate().isNotEmpty ? plain : find.text('$label *')).first;
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

String currentLocation(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  return GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();
}

Future<void> settleSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}
