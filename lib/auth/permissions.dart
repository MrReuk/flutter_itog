import 'role.dart';

enum Permission {
  browse('Просмотр афиши, фильмов и расписания'),
  manageCatalog('Создание, изменение и удаление фильмов, жанров, персон, залов и сеансов'),
  buyTickets('Покупка билетов для себя'),
  viewOwnTickets('Просмотр собственных заказов и билетов'),
  editProfile('Редактирование профиля зрителя'),
  useBoxOffice('Касса: продажа билетов на месте'),
  viewOrders('Просмотр всех заказов'),
  checkTickets('Контроль билетов, возврат'),
  manageUsers('Управление пользователями и ролями');

  const Permission(this.title);

  final String title;
}

const Set<Role> _everyone = {Role.viewer, Role.cashier, Role.admin};
const Set<Role> _staff = {Role.cashier, Role.admin};

const Map<Permission, Set<Role>> kPermissionRoles = {
  Permission.browse: _everyone,
  Permission.manageCatalog: {Role.admin},
  Permission.buyTickets: {Role.viewer},
  Permission.viewOwnTickets: {Role.viewer},
  Permission.editProfile: {Role.viewer},
  Permission.useBoxOffice: {Role.cashier},
  Permission.viewOrders: _staff,
  Permission.checkTickets: _staff,
  Permission.manageUsers: {Role.admin},
};

bool roleCan(Role? role, Permission permission) {
  if (role == null) return false;
  return kPermissionRoles[permission]?.contains(role) ?? false;
}
