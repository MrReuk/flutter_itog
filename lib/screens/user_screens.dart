import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_user.dart';
import '../auth/auth_notifier.dart';
import '../auth/password_rules.dart';
import '../auth/role.dart';
import '../models/list_query.dart';
import '../models/named_option.dart';
import '../repositories/user_repositories.dart';
import '../validation/validators.dart';
import '../widgets/choice_dropdown.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_table.dart';
import 'entity_form_screen.dart';
import 'entity_list_screen.dart';

List<NamedOption> roleOptions() => [for (final r in Role.values) (id: r.code, name: r.label)];

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key, required this.query});

  final ListQuery query;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthNotifier>().user;
    return EntityListScreen<AppUser>(
      title: 'Пользователи',
      path: '/admin/users',
      query: query,
      searchLabel: 'Поиск по имени или почте',
      emptyMessage: 'Пользователи не найдены. Измените поиск или фильтры.',
      canManage: true,
      selectable: false,
      addLabel: 'Добавить пользователя',
      newPath: '/admin/users/new',
      editPath: (u) => '/admin/users/${u.id}/edit',
      canDelete: (u) => u.id != me?.id,
      idOf: (u) => u.id,
      titleOf: (u) => u.name,
      subtitleOf: (u) => '${u.email}\n${u.role.label}',
      filters: (context, q, apply) => [
        ChoiceDropdown(
          label: 'Роль',
          value: q.filter('role'),
          choices: [for (final r in Role.values) (value: r.code, label: r.label)],
          onChanged: (value) => apply(q.withFilter('role', value)),
        ),
      ],
      columns: [
        TableColumnSpec<AppUser>(label: 'Имя', sortField: 'name', build: (u) => Text(u.name)),
        TableColumnSpec<AppUser>(label: 'Почта', sortField: 'email', build: (u) => Text(u.email)),
        TableColumnSpec<AppUser>(
          label: 'Роль',
          sortField: 'role',
          build: (u) => Text(u.role.label),
        ),
      ],
    );
  }
}

class UserFormScreen extends StatelessWidget {
  const UserFormScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    final users = context.read<UserRepository>();
    final auth = context.read<AuthNotifier>();
    final id = userId;
    return EntityFormScreen<AppUser>(
      title: id == null ? 'Новый пользователь' : 'Редактирование пользователя',
      backPath: '/admin/users',
      notFoundMessage: 'Пользователь не найден',
      savedMessage: id == null ? 'Пользователь добавлен' : 'Изменения сохранены',
      loadItem: id == null ? null : () => users.findById(id),
      initialValues: (u) => {
        'name': u?.name ?? '',
        'email': u?.email ?? '',
        'role': u?.role.code ?? Role.viewer.code,
        'password': '',
      },
      fields: (u) => [
        FieldSpec.text(
          key: 'name',
          label: 'Имя',
          required: true,
          maxLength: 80,
          validator: checks([notBlank(), minLength(2), maxLength(80)]),
        ),
        if (u == null) ...[
          FieldSpec.text(
            key: 'email',
            label: 'Почта',
            required: true,
            keyboardType: TextInputType.emailAddress,
            validator: checks([notBlank(), emailFormat()]),
          ),
          FieldSpec.text(
            key: 'password',
            label: 'Пароль',
            required: true,
            obscure: true,
            hint: 'Не короче 8 символов, цифра и специальный символ',
            validator: (value, _) => passwordError(value),
          ),
        ],
        FieldSpec.dropdown(
          key: 'role',
          label: 'Роль',
          required: true,
          options: (_) => roleOptions(),
          validator: (value) {
            if (value == null) return 'Выберите роль';
            if (u != null && u.id == auth.user?.id && value != Role.admin.code) {
              return 'Нельзя снять с себя роль администратора';
            }
            return null;
          },
        ),
      ],
      save: (values, existing) async {
        final role = Role.tryParse(values['role']) ?? Role.viewer;
        final name = (values['name'] as String).trim();
        if (existing == null) {
          await users.createUser(
            email: values['email'] as String,
            name: name,
            role: role,
            password: values['password'] as String,
          );
        } else {
          await users.updateUser(id: existing.id, name: name, role: role);
        }
      },
    );
  }
}
