import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/genre.dart';
import '../models/hall.dart';
import '../models/json_helpers.dart';
import '../models/list_query.dart';
import '../models/movie.dart';
import '../models/named_option.dart';
import '../models/person.dart';
import '../repositories/catalog_repositories.dart';
import '../state/reference_notifier.dart';
import '../validation/validators.dart';
import '../widgets/choice_dropdown.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_table.dart';
import '../widgets/id_dropdown.dart';
import 'entity_form_screen.dart';
import 'entity_list_screen.dart';

bool _canManage(BuildContext context) =>
    context.watch<AuthNotifier>().can(Permission.manageCatalog);

List<NamedOption> fixedOptions(List<String> values) => [for (final v in values) (id: v, name: v)];

class GenreListScreen extends StatelessWidget {
  const GenreListScreen({super.key, required this.query});

  final ListQuery query;

  @override
  Widget build(BuildContext context) {
    return EntityListScreen<Genre>(
      title: 'Жанры',
      path: '/genres',
      query: query,
      searchLabel: 'Поиск по названию',
      emptyMessage: 'Жанры не найдены.',
      canManage: _canManage(context),
      addLabel: 'Добавить жанр',
      newPath: '/genres/new',
      editPath: (g) => '/genres/${g.id}/edit',
      reloadReferences: true,
      idOf: (g) => g.id,
      titleOf: (g) => g.title,
      subtitleOf: (g) => '',
      columns: [
        TableColumnSpec<Genre>(
          label: 'Название',
          sortField: 'title',
          build: (g) => CellText(g.title),
        ),
      ],
    );
  }
}

class GenreFormScreen extends StatelessWidget {
  const GenreFormScreen({super.key, this.genreId});

  final String? genreId;

  @override
  Widget build(BuildContext context) {
    final genres = context.read<GenreRepository>();
    final id = genreId;
    return EntityFormScreen<Genre>(
      title: id == null ? 'Новый жанр' : 'Редактирование жанра',
      backPath: '/genres',
      notFoundMessage: 'Жанр не найден',
      savedMessage: id == null ? 'Жанр добавлен' : 'Изменения сохранены',
      loadItem: id == null ? null : () => genres.findById(id),
      initialValues: (g) => {'title': g?.title ?? ''},
      fields: (g) => [
        FieldSpec.text(
          key: 'title',
          label: 'Название',
          required: true,
          maxLength: 40,
          validator: checks([notBlank(), minLength(2), maxLength(40)]),
        ),
      ],
      save: (values, existing) async {
        final draft = Genre(id: existing?.id ?? '', title: (values['title'] as String).trim());
        if (existing == null) {
          await genres.create(draft);
        } else {
          await genres.update(draft);
        }
      },
    );
  }
}

class PersonListScreen extends StatelessWidget {
  const PersonListScreen({super.key, required this.query});

  final ListQuery query;

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceNotifier>();
    return EntityListScreen<Person>(
      title: 'Персоны',
      path: '/people',
      query: query,
      searchLabel: 'Поиск по имени',
      emptyMessage: 'Персоны не найдены. Измените поиск или фильтры.',
      canManage: _canManage(context),
      addLabel: 'Добавить персону',
      newPath: '/people/new',
      editPath: (p) => '/people/${p.id}/edit',
      reloadReferences: true,
      idOf: (p) => p.id,
      titleOf: (p) => p.fullName,
      subtitleOf: (p) => [
        if (p.country.isNotEmpty) p.country,
        if (p.birthDate != null) 'родился ${formatRuDate(p.birthDate!.toLocal())}',
      ].join(' · '),
      filters: (context, q, apply) => [
        ChoiceDropdown(
          label: 'Страна',
          value: q.filter('country'),
          choices: [for (final c in refs.countries()) (value: c, label: c)],
          onChanged: (value) => apply(q.withFilter('country', value)),
        ),
      ],
      columns: [
        TableColumnSpec<Person>(
          label: 'Имя',
          sortField: 'fullName',
          build: (p) => CellText(p.fullName),
        ),
        TableColumnSpec<Person>(
          label: 'Страна',
          sortField: 'country',
          build: (p) => Text(p.country.isEmpty ? '—' : p.country),
        ),
        TableColumnSpec<Person>(
          label: 'Дата рождения',
          hideBelow: 900,
          build: (p) => Text(p.birthDate == null ? '—' : formatRuDate(p.birthDate!.toLocal())),
        ),
      ],
    );
  }
}

class PersonFormScreen extends StatelessWidget {
  const PersonFormScreen({super.key, this.personId});

  final String? personId;

  @override
  Widget build(BuildContext context) {
    final people = context.read<PersonRepository>();
    final id = personId;
    return EntityFormScreen<Person>(
      title: id == null ? 'Новая персона' : 'Редактирование персоны',
      backPath: '/people',
      notFoundMessage: 'Персона не найдена',
      savedMessage: id == null ? 'Персона добавлена' : 'Изменения сохранены',
      loadItem: id == null ? null : () => people.findById(id),
      initialValues: (p) => {
        'fullName': p?.fullName ?? '',
        'country': p?.country ?? '',
        'birthDate': p?.birthDate == null ? '' : formatRuDate(p!.birthDate!.toLocal()),
      },
      fields: (p) => [
        FieldSpec.text(
          key: 'fullName',
          label: 'Имя и фамилия',
          required: true,
          maxLength: 80,
          validator: checks([notBlank(), minLength(2), maxLength(80), namePattern()]),
        ),
        FieldSpec.text(
          key: 'country',
          label: 'Страна',
          maxLength: 60,
          validator: checks([maxLength(60)]),
        ),
        FieldSpec.text(
          key: 'birthDate',
          label: 'Дата рождения',
          hint: '31.12.1980',
          isDate: true,
          validator: checks([dateFormat()]),
        ),
      ],
      save: (values, existing) async {
        final birth = parseRuDate(values['birthDate'] as String);
        final draft = Person(
          id: existing?.id ?? '',
          fullName: (values['fullName'] as String).trim(),
          country: (values['country'] as String).trim(),
          birthDate: birth,
        );
        if (existing == null) {
          await people.create(draft);
        } else {
          await people.update(draft);
        }
      },
    );
  }
}

class HallListScreen extends StatelessWidget {
  const HallListScreen({super.key, required this.query});

  final ListQuery query;

  @override
  Widget build(BuildContext context) {
    return EntityListScreen<Hall>(
      title: 'Залы',
      path: '/halls',
      query: query,
      searchLabel: 'Поиск по названию',
      emptyMessage: 'Залы не найдены. Измените поиск или фильтры.',
      canManage: _canManage(context),
      addLabel: 'Добавить зал',
      newPath: '/halls/new',
      editPath: (h) => '/halls/${h.id}/edit',
      reloadReferences: true,
      idOf: (h) => h.id,
      titleOf: (h) => '${h.name} (${h.format})',
      subtitleOf: (h) =>
          '${h.rows} рядов × ${h.seatsPerRow} мест = ${h.seats} мест\nКоэффициент цены: ${h.priceFactor}',
      filters: (context, q, apply) => [
        ChoiceDropdown(
          label: 'Формат',
          value: q.filter('format'),
          choices: [for (final f in kHallFormats) (value: f, label: f)],
          onChanged: (value) => apply(q.withFilter('format', value)),
        ),
      ],
      columns: [
        TableColumnSpec<Hall>(label: 'Название', sortField: 'name', build: (h) => Text(h.name)),
        TableColumnSpec<Hall>(label: 'Формат', build: (h) => Text(h.format)),
        TableColumnSpec<Hall>(
          label: 'Рядов',
          sortField: 'rows',
          numeric: true,
          build: (h) => Text('${h.rows}'),
        ),
        TableColumnSpec<Hall>(
          label: 'Мест в ряду',
          numeric: true,
          hideBelow: 900,
          build: (h) => Text('${h.seatsPerRow}'),
        ),
        TableColumnSpec<Hall>(
          label: 'Вместимость',
          numeric: true,
          build: (h) => Text('${h.seats}'),
        ),
        TableColumnSpec<Hall>(
          label: 'Коэффициент цены',
          sortField: 'priceFactor',
          numeric: true,
          hideBelow: 1000,
          build: (h) => Text('${h.priceFactor}'),
        ),
      ],
    );
  }
}

class HallFormScreen extends StatelessWidget {
  const HallFormScreen({super.key, this.hallId});

  final String? hallId;

  @override
  Widget build(BuildContext context) {
    final halls = context.read<HallRepository>();
    final id = hallId;
    return EntityFormScreen<Hall>(
      title: id == null ? 'Новый зал' : 'Редактирование зала',
      backPath: '/halls',
      notFoundMessage: 'Зал не найден',
      savedMessage: id == null ? 'Зал добавлен' : 'Изменения сохранены',
      loadItem: id == null ? null : () => halls.findById(id),
      initialValues: (h) => {
        'name': h?.name ?? '',
        'format': h?.format ?? '2D',
        'rows': h == null ? '' : '${h.rows}',
        'seatsPerRow': h == null ? '' : '${h.seatsPerRow}',
        'priceFactor': h == null ? '1' : '${h.priceFactor}',
      },
      fields: (h) => [
        FieldSpec.text(
          key: 'name',
          label: 'Название',
          required: true,
          maxLength: 40,
          validator: checks([notBlank(), minLength(2), maxLength(40)]),
        ),
        FieldSpec.dropdown(
          key: 'format',
          label: 'Формат',
          required: true,
          options: (_) => fixedOptions(kHallFormats),
          validator: mustChoose('Выберите формат'),
        ),
        FieldSpec.group(
          title: 'Схема зала',
          fields: [
            FieldSpec.text(
              key: 'rows',
              label: 'Количество рядов',
              required: true,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: checks([notBlank(), integerInRange(1, 20)]),
            ),
            FieldSpec.text(
              key: 'seatsPerRow',
              label: 'Мест в ряду',
              required: true,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: checks([notBlank(), integerInRange(1, 30)]),
            ),
          ],
        ),
        FieldSpec.text(
          key: 'priceFactor',
          label: 'Коэффициент цены',
          required: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: checks([notBlank(), decimalInRange(0.5, 3)]),
        ),
      ],
      save: (values, existing) async {
        final draft = Hall(
          id: existing?.id ?? '',
          name: (values['name'] as String).trim(),
          format: values['format'] as String? ?? '2D',
          rows: jsonInt(values['rows']),
          seatsPerRow: jsonInt(values['seatsPerRow']),
          priceFactor: jsonDouble((values['priceFactor'] as String).replaceAll(',', '.'), 1),
        );
        if (existing == null) {
          await halls.create(draft);
        } else {
          await halls.update(draft);
        }
      },
    );
  }
}

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, required this.query});

  final ListQuery query;

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceNotifier>();
    return EntityListScreen<Movie>(
      title: 'Фильмы',
      path: '/movies',
      query: query,
      searchLabel: 'Поиск по названию или стране',
      emptyMessage: 'Фильмы не найдены. Измените поиск или фильтры.',
      canManage: _canManage(context),
      addLabel: 'Добавить фильм',
      newPath: '/movies/new',
      editPath: (m) => '/movies/${m.id}/edit',
      openPath: (m) => '/movies/${m.id}',
      reloadReferences: true,
      idOf: (m) => m.id,
      titleOf: (m) => m.title,
      subtitleOf: (m) =>
          '${m.genreTitles.join(', ')}\n${m.year} · ${m.durationText} · ${m.ageRating}',
      filters: (context, q, apply) => movieFilters(refs, q, apply),
      columns: [
        TableColumnSpec<Movie>(
          label: 'Название',
          sortField: 'title',
          build: (m) => CellText(m.title, maxWidth: 280),
        ),
        TableColumnSpec<Movie>(
          label: 'Жанры',
          build: (m) => CellText(m.genreTitles.join(', '), maxWidth: 200),
        ),
        TableColumnSpec<Movie>(
          label: 'Год',
          sortField: 'year',
          numeric: true,
          build: (m) => Text('${m.year}'),
        ),
        TableColumnSpec<Movie>(
          label: 'Длительность',
          sortField: 'durationMin',
          hideBelow: 900,
          build: (m) => Text(m.durationText),
        ),
        TableColumnSpec<Movie>(label: 'Возраст', build: (m) => Text(m.ageRating)),
        TableColumnSpec<Movie>(
          label: 'Страна',
          hideBelow: 1100,
          build: (m) => Text(m.country.isEmpty ? '—' : m.country),
        ),
      ],
    );
  }
}

List<Widget> movieFilters(ReferenceNotifier refs, ListQuery q, void Function(ListQuery) apply) {
  Widget yearField(String key, String label) {
    return SizedBox(
      width: 110,
      child: DebouncedTextField(
        value: q.filter(key),
        onChanged: (text) => apply(q.withFilter(key, text.trim())),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  return [
    IdDropdown(
      label: 'Жанр',
      value: q.filter('genre').isEmpty ? null : q.filter('genre'),
      options: refs.genreOptions(),
      onChanged: (value) => apply(q.withFilter('genre', value ?? '')),
    ),
    ChoiceDropdown(
      label: 'Возраст',
      value: q.filter('age'),
      width: 140,
      choices: [for (final a in kAgeRatings) (value: a, label: a)],
      onChanged: (value) => apply(q.withFilter('age', value)),
    ),
    yearField('yearFrom', 'Год от'),
    yearField('yearTo', 'Год до'),
  ];
}

class MovieFormScreen extends StatelessWidget {
  const MovieFormScreen({super.key, this.movieId});

  final String? movieId;

  @override
  Widget build(BuildContext context) {
    final movies = context.read<MovieRepository>();
    final refs = context.read<ReferenceNotifier>();
    final id = movieId;
    return EntityFormScreen<Movie>(
      title: id == null ? 'Новый фильм' : 'Редактирование фильма',
      backPath: '/movies',
      notFoundMessage: 'Фильм не найден',
      savedMessage: id == null ? 'Фильм добавлен' : 'Изменения сохранены',
      needsRefs: true,
      loadItem: id == null ? null : () => movies.findById(id),
      initialValues: (m) => {
        'title': m?.title ?? '',
        'year': m == null ? '' : '${m.year}',
        'durationMin': m == null ? '' : '${m.durationMin}',
        'ageRating': m?.ageRating ?? '12+',
        'country': m?.country ?? '',
        'description': m?.description ?? '',
        'genres': m?.genreIds ?? <String>[],
        'directors': m?.directorIds ?? <String>[],
        'actors': m?.actorIds ?? <String>[],
      },
      fields: (m) => [
        FieldSpec.text(
          key: 'title',
          label: 'Название',
          required: true,
          maxLength: 120,
          validator: checks([notBlank(), maxLength(120)]),
        ),
        FieldSpec.group(
          title: 'Основное',
          fields: [
            FieldSpec.text(
              key: 'year',
              label: 'Год выхода',
              required: true,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: checks([notBlank(), integerInRange(1900, 2100)]),
            ),
            FieldSpec.text(
              key: 'durationMin',
              label: 'Длительность, минут',
              required: true,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: checks([notBlank(), integerInRange(1, 400)]),
            ),
            FieldSpec.dropdown(
              key: 'ageRating',
              label: 'Возрастное ограничение',
              required: true,
              options: (_) => fixedOptions(kAgeRatings),
              validator: mustChoose('Выберите ограничение'),
            ),
            FieldSpec.text(
              key: 'country',
              label: 'Страна',
              maxLength: 60,
              validator: checks([maxLength(60)]),
            ),
          ],
        ),
        FieldSpec.multi(
          key: 'genres',
          label: 'Жанры',
          required: true,
          options: (_) => refs.genreOptions(),
          validator: (value) {
            if (value.isEmpty) return 'Выберите хотя бы один жанр';
            if (value.length > 5) return 'Не больше пяти жанров';
            return null;
          },
        ),
        FieldSpec.multi(
          key: 'directors',
          label: 'Режиссёры',
          options: (_) => refs.personOptions(),
          validator: (value) => value.length > 5 ? 'Не больше пяти режиссёров' : null,
        ),
        FieldSpec.multi(
          key: 'actors',
          label: 'Актёры',
          options: (_) => refs.personOptions(),
          validator: (value) => value.length > 20 ? 'Не больше двадцати актёров' : null,
        ),
        FieldSpec.text(
          key: 'description',
          label: 'Описание',
          maxLength: 2000,
          maxLines: 5,
          validator: checks([maxLength(2000)]),
        ),
      ],
      save: (values, existing) async {
        final draft = Movie(
          id: existing?.id ?? '',
          title: (values['title'] as String).trim(),
          description: (values['description'] as String).trim(),
          year: jsonInt(values['year']),
          durationMin: jsonInt(values['durationMin']),
          ageRating: values['ageRating'] as String? ?? '12+',
          country: (values['country'] as String).trim(),
          genreIds: List<String>.from(values['genres'] as List),
          directorIds: List<String>.from(values['directors'] as List),
          actorIds: List<String>.from(values['actors'] as List),
        );
        if (existing == null) {
          await movies.create(draft);
        } else {
          await movies.update(draft);
        }
      },
    );
  }
}
