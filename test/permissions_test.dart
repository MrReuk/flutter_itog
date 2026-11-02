import 'package:atrium_cinema/auth/permissions.dart';
import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/auth/route_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Таблица прав по ролям', () {
    Set<Permission> allowed(Role role) => {
      for (final p in Permission.values)
        if (roleCan(role, p)) p,
    };

    test('зритель покупает билеты и ведёт профиль, но ничего не меняет в каталоге', () {
      expect(allowed(Role.viewer), {
        Permission.browse,
        Permission.buyTickets,
        Permission.viewOwnTickets,
        Permission.editProfile,
      });
    });

    test('кассир продаёт на месте и видит все заказы, но не правит каталог', () {
      expect(allowed(Role.cashier), {
        Permission.browse,
        Permission.useBoxOffice,
        Permission.viewOrders,
        Permission.checkTickets,
      });
    });

    test('администратор управляет каталогом и пользователями', () {
      expect(allowed(Role.admin), {
        Permission.browse,
        Permission.manageCatalog,
        Permission.viewOrders,
        Permission.checkTickets,
        Permission.manageUsers,
      });
    });

    test('у каждой роли есть раздел, закрытый для остальных', () {
      final unique = {
        Role.viewer: Permission.viewOwnTickets,
        Role.cashier: Permission.useBoxOffice,
        Role.admin: Permission.manageUsers,
      };

      for (final entry in unique.entries) {
        for (final role in Role.values) {
          expect(
            roleCan(role, entry.value),
            role == entry.key,
            reason: '${role.code} / ${entry.value.name}',
          );
        }
      }
    });

    test('без входа не разрешено ничего', () {
      for (final p in Permission.values) {
        expect(roleCan(null, p), isFalse);
      }
    });
  });

  group('Какое право нужно для адреса', () {
    Permission? need(String location) => requiredPermission(location);

    test('афиша, фильмы и сеансы открыты всем вошедшим', () {
      expect(need('/'), isNull);
      expect(need('/movies'), Permission.browse);
      expect(need('/movies/m1'), Permission.browse);
      expect(need('/screenings'), Permission.browse);
      expect(need('/screenings/s1'), Permission.browse);
      expect(need('/movies?genre=g1&page=2'), Permission.browse);
    });

    test('создание и изменение — только администратор', () {
      expect(need('/movies/new'), Permission.manageCatalog);
      expect(need('/movies/m1/edit'), Permission.manageCatalog);
      expect(need('/screenings/new'), Permission.manageCatalog);
      expect(need('/screenings/s1/edit'), Permission.manageCatalog);
    });

    test('справочники закрыты для всех, кроме администратора', () {
      for (final path in ['/genres', '/genres/new', '/people', '/halls', '/halls/h1/edit']) {
        expect(need(path), Permission.manageCatalog, reason: path);
      }
    });

    test('личный раздел зрителя', () {
      expect(need('/my/tickets'), Permission.viewOwnTickets);
      expect(need('/my/profile'), Permission.editProfile);
    });

    test('разделы персонала', () {
      expect(need('/box-office'), Permission.useBoxOffice);
      expect(need('/orders'), Permission.viewOrders);
      expect(need('/orders/o1'), Permission.viewOrders);
      expect(need('/tickets'), Permission.checkTickets);
      expect(need('/admin/users'), Permission.manageUsers);
      expect(need('/admin/users/new'), Permission.manageUsers);
    });

    test('неизвестный адрес не требует особых прав', () {
      expect(need('/nowhere'), isNull);
    });
  });

  group('Безопасный возврат после входа', () {
    test('внутренние адреса принимаются', () {
      expect(safeReturnTo('/movies?genre=g1'), '/movies?genre=g1');
      expect(safeReturnTo('/my/tickets'), '/my/tickets');
    });

    test('чужие и служебные адреса отвергаются', () {
      for (final value in [
        null,
        '',
        '//evil.example',
        'https://evil.example',
        r'/a\b',
        '/login',
        '/register',
        '/forbidden',
        '/offline',
      ]) {
        expect(safeReturnTo(value), isNull, reason: '$value');
      }
    });

    test('публичные пути', () {
      expect(isPublicPath('/login'), isTrue);
      expect(isPublicPath('/register'), isTrue);
      expect(isPublicPath('/movies'), isFalse);
    });
  });
}
