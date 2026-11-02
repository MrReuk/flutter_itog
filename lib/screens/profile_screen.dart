import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../models/json_helpers.dart';
import '../models/named_option.dart';
import '../models/viewer_profile.dart';
import '../repositories/user_repositories.dart';
import '../state/reference_notifier.dart';
import '../validation/validators.dart';
import '../widgets/entity_form.dart';
import 'entity_form_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profiles = context.read<ProfileRepository>();
    final refs = context.read<ReferenceNotifier>();
    final userId = context.read<AuthNotifier>().user?.id ?? '';
    const yesNo = <NamedOption>[(id: 'yes', name: 'Да'), (id: 'no', name: 'Нет')];
    return EntityFormScreen<ViewerProfile>(
      title: 'Мой профиль',
      backPath: '/',
      notFoundMessage: 'Профиль не найден. Выйдите и войдите снова.',
      savedMessage: 'Профиль сохранён',
      needsRefs: true,
      loadItem: () => profiles.forUser(userId),
      initialValues: (p) => {
        'phone': p?.phone ?? '',
        'birthDate': p?.birthDate == null ? '' : formatRuDate(p!.birthDate!.toLocal()),
        'student': (p?.student ?? false) ? 'yes' : 'no',
        'favoriteGenre': p?.favoriteGenreId,
      },
      fields: (p) => [
        FieldSpec.text(
          key: 'phone',
          label: 'Телефон',
          hint: '+7 900 123-45-67',
          keyboardType: TextInputType.phone,
          maxLength: 20,
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]'))],
          validator: checks([phoneFormat()]),
        ),
        FieldSpec.text(
          key: 'birthDate',
          label: 'Дата рождения',
          hint: '31.12.2000',
          isDate: true,
          validator: checks([dateFormat()]),
        ),
        FieldSpec.dropdown(
          key: 'student',
          label: 'Студент (студенческий билет со скидкой)',
          options: (_) => yesNo,
        ),
        FieldSpec.dropdown(
          key: 'favoriteGenre',
          label: 'Любимый жанр',
          options: (_) => refs.genreOptions(),
        ),
      ],
      save: (values, existing) async {
        if (existing == null) return;
        await profiles.save(
          ViewerProfile(
            id: existing.id,
            userId: existing.userId,
            phone: (values['phone'] as String).trim(),
            birthDate: parseRuDate(values['birthDate'] as String),
            student: values['student'] == 'yes',
            favoriteGenreId: jsonString(values['favoriteGenre']),
          ),
        );
      },
    );
  }
}
