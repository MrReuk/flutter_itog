enum Role {
  viewer('viewer', 'Зритель'),
  cashier('cashier', 'Кассир'),
  admin('admin', 'Администратор');

  const Role(this.code, this.label);

  final String code;
  final String label;

  static Role? tryParse(Object? value) {
    for (final role in Role.values) {
      if (role.code == value) return role;
    }
    return null;
  }
}
