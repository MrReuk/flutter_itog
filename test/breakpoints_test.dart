import 'package:atrium_cinema/core/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Классы ширины окна', () {
    test('границы 360, 599, 600, 1199, 1200, 1920', () {
      expect(screenSizeForWidth(360), ScreenSize.compact);
      expect(screenSizeForWidth(599.9), ScreenSize.compact);
      expect(screenSizeForWidth(600), ScreenSize.medium);
      expect(screenSizeForWidth(1199.9), ScreenSize.medium);
      expect(screenSizeForWidth(1200), ScreenSize.expanded);
      expect(screenSizeForWidth(1920), ScreenSize.expanded);
    });

    test('значение по классу окна: не заданное берётся от ближайшего меньшего', () {
      expect(pickByScreen(ScreenSize.compact, compact: 1, medium: 2, expanded: 3), 1);
      expect(pickByScreen(ScreenSize.medium, compact: 1, medium: 2, expanded: 3), 2);
      expect(pickByScreen(ScreenSize.expanded, compact: 1, medium: 2, expanded: 3), 3);
      expect(pickByScreen(ScreenSize.expanded, compact: 1, medium: 2), 2);
      expect(pickByScreen(ScreenSize.expanded, compact: 1), 1);
      expect(pickByScreen(ScreenSize.medium, compact: 1), 1);
    });
  });

  group('Сетка карточек', () {
    test('число колонок растёт с шириной, но не меньше одной', () {
      expect(gridColumns(332, minTile: 160), 2);
      expect(gridColumns(100, minTile: 160), 1);
      expect(gridColumns(0, minTile: 160), 1);
      expect(gridColumns(1280, minTile: 200), 6);
      expect(gridColumns(1280, minTile: 0), 1);
    });
  });

  test('таблица заменяется карточками на узких экранах', () {
    expect(kTableMinWidth, lessThan(kMediumBreakpoint + 200));
    expect(kContentMaxWidth, greaterThanOrEqualTo(1200));
  });
}
