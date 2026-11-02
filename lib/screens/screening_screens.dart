import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/format.dart';
import '../models/json_helpers.dart';
import '../models/list_query.dart';
import '../models/pricing.dart';
import '../models/screening.dart';
import '../models/ticket.dart';
import '../repositories/screening_repository.dart';
import '../state/reference_notifier.dart';
import '../validation/validators.dart';
import '../widgets/choice_dropdown.dart';
import '../widgets/date_filter_field.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_table.dart';
import '../widgets/id_dropdown.dart';
import 'catalog_screens.dart';
import 'entity_form_screen.dart';
import 'entity_list_screen.dart';

const List<({String value, String label})> kPeriodChoices = [
  (value: 'upcoming', label: 'Предстоящие'),
  (value: 'past', label: 'Прошедшие'),
  (value: 'all', label: 'Все'),
];

class ScreeningListScreen extends StatelessWidget {
  const ScreeningListScreen({
    super.key,
    required this.query,
    this.boxOffice = false,
    this.path = '/screenings',
  });

  final ListQuery query;
  final bool boxOffice;
  final String path;

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceNotifier>();
    final auth = context.watch<AuthNotifier>();
    final canManage = auth.can(Permission.manageCatalog);
    final canSell = auth.can(Permission.buyTickets) || auth.can(Permission.useBoxOffice);

    return EntityListScreen<Screening>(
      title: boxOffice ? 'Касса' : 'Сеансы',
      path: path,
      query: query,
      searchLabel: 'Поиск по названию фильма',
      emptyMessage: 'Сеансы не найдены. Измените поиск или фильтры.',
      canManage: canManage && !boxOffice,
      addLabel: 'Добавить сеанс',
      newPath: '/screenings/new',
      editPath: (s) => '/screenings/${s.id}/edit',
      openPath: (s) => '/screenings/${s.id}',
      idOf: (s) => s.id,
      titleOf: (s) => '${s.movieTitle}, ${formatCinemaShort(s.startsAt)}',
      subtitleOf: (s) => '${s.hallName} · ${s.language}\nБазовая цена: ${formatRub(s.basePrice)}',
      deleteName: (s) => '${s.movieTitle}, ${formatCinemaShort(s.startsAt)}',
      header: boxOffice ? _BoxOfficeHeader(query: query, path: path) : null,
      extraActions: (context, s) => [
        IconButton(
          tooltip: canSell ? 'Выбрать места' : 'Схема зала',
          icon: Icon(canSell ? Icons.event_seat : Icons.grid_view),
          onPressed: () => context.push('/screenings/${s.id}'),
        ),
      ],
      filters: (context, q, apply) => [
        IdDropdown(
          label: 'Фильм',
          value: q.filter('movie').isEmpty ? null : q.filter('movie'),
          options: refs.movieOptions(),
          width: 260,
          onChanged: (value) => apply(q.withFilter('movie', value ?? '')),
        ),
        IdDropdown(
          label: 'Зал',
          value: q.filter('hall').isEmpty ? null : q.filter('hall'),
          options: refs.hallOptions(),
          onChanged: (value) => apply(q.withFilter('hall', value ?? '')),
        ),
        DateFilterField(
          label: 'Дата',
          value: q.filter('date'),
          onChanged: (value) => apply(q.withFilter('date', value)),
        ),
        ChoiceDropdown(
          label: 'Язык',
          value: q.filter('language'),
          choices: [for (final l in kLanguages) (value: l, label: l)],
          onChanged: (value) => apply(q.withFilter('language', value)),
        ),
        ChoiceDropdown(
          label: 'Период',
          value: q.filter('period'),
          width: 170,
          allLabel: null,
          choices: kPeriodChoices,
          onChanged: (value) => apply(q.withFilter('period', value)),
        ),
      ],
      columns: [
        TableColumnSpec<Screening>(
          label: 'Фильм',
          sortField: 'movie',
          build: (s) => CellText(s.movieTitle, maxWidth: 280),
        ),
        TableColumnSpec<Screening>(
          label: 'Начало',
          sortField: 'startsAt',
          build: (s) => Text(formatCinemaShort(s.startsAt)),
        ),
        TableColumnSpec<Screening>(label: 'Зал', build: (s) => Text(s.hallName)),
        TableColumnSpec<Screening>(label: 'Язык', hideBelow: 950, build: (s) => Text(s.language)),
        TableColumnSpec<Screening>(
          label: 'Базовая цена',
          sortField: 'basePrice',
          numeric: true,
          build: (s) => Text(formatRub(s.basePrice)),
        ),
      ],
    );
  }
}

class _BoxOfficeHeader extends StatelessWidget {
  const _BoxOfficeHeader({required this.query, required this.path});

  final ListQuery query;
  final String path;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = isoCinemaDate(now);
    final tomorrow = isoCinemaDate(now.add(const Duration(days: 1)));
    final current = query.filter('date');

    Widget chip(String label, String date) {
      return ChoiceChip(
        label: Text(label),
        selected: current == date,
        onSelected: (_) => context.go(query.withFilter('date', date).toLocation(path)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Продажа билетов на месте:', style: Theme.of(context).textTheme.titleSmall),
            chip('Сегодня', today),
            chip('Завтра', tomorrow),
            chip('Все предстоящие', ''),
          ],
        ),
      ),
    );
  }
}

class ScreeningFormScreen extends StatelessWidget {
  const ScreeningFormScreen({super.key, this.screeningId});

  final String? screeningId;

  @override
  Widget build(BuildContext context) {
    final screenings = context.read<ScreeningRepository>();
    final refs = context.read<ReferenceNotifier>();
    final id = screeningId;
    return EntityFormScreen<Screening>(
      title: id == null ? 'Новый сеанс' : 'Редактирование сеанса',
      backPath: '/screenings',
      notFoundMessage: 'Сеанс не найден',
      savedMessage: id == null ? 'Сеанс добавлен' : 'Изменения сохранены',
      needsRefs: true,
      loadItem: id == null ? null : () => screenings.findById(id),
      initialValues: (s) => {
        'movie': s?.movieId,
        'hall': s?.hallId,
        'startsAt': s == null ? '' : formatCinemaDateTime(s.startsAt),
        'basePrice': s == null ? '300' : '${s.basePrice}',
        'language': s?.language ?? kLanguages.first,
      },
      fields: (s) => [
        FieldSpec.dropdown(
          key: 'movie',
          label: 'Фильм',
          required: true,
          options: (_) => refs.movieOptions(),
          validator: mustChoose('Выберите фильм'),
        ),
        FieldSpec.dropdown(
          key: 'hall',
          label: 'Зал',
          required: true,
          options: (_) => refs.hallOptions(),
          validator: mustChoose('Выберите зал'),
        ),
        FieldSpec.text(
          key: 'startsAt',
          label: 'Начало',
          required: true,
          hint: '31.12.2026 18:30',
          isDateTime: true,
          validator: checks([notBlank(), dateTimeFormat()]),
        ),
        FieldSpec.text(
          key: 'basePrice',
          label: 'Базовая цена, ₽',
          required: true,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          validator: checks([notBlank(), integerInRange(50, 10000)]),
        ),
        FieldSpec.dropdown(
          key: 'language',
          label: 'Язык',
          required: true,
          options: (_) => fixedOptions(kLanguages),
          validator: mustChoose('Выберите язык'),
        ),
      ],
      save: (values, existing) async {
        final fields = parseRuDateTime(values['startsAt'] as String);
        final draft = Screening(
          id: existing?.id ?? '',
          movieId: values['movie'] as String? ?? '',
          hallId: values['hall'] as String? ?? '',
          startsAt: fromCinemaFields(fields ?? DateTime.now()),
          basePrice: jsonInt(values['basePrice']),
          language: values['language'] as String? ?? kLanguages.first,
        );
        if (existing == null) {
          await screenings.create(draft);
        } else {
          await screenings.update(draft);
        }
      },
    );
  }
}

int priceOf(Screening s, TicketCategory category) {
  final hall = s.hall;
  if (hall == null) return s.basePrice;
  return ticketPrice(
    basePrice: s.basePrice,
    hallFactor: hall.priceFactor,
    category: category,
    startsAt: s.startsAt,
  );
}
