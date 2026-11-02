import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/format.dart';
import '../models/list_query.dart';
import '../models/list_specs.dart';
import '../models/movie.dart';
import '../models/pricing.dart';
import '../models/screening.dart';
import '../models/ticket.dart';
import '../repositories/catalog_repositories.dart';
import '../repositories/screening_repository.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/detail_layout.dart';
import '../widgets/state_views.dart';
import 'afisha_screen.dart';

typedef _MoviePage = ({Movie? movie, List<Screening> screenings});

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Future<_MoviePage> _loading;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<_MoviePage> _load() async {
    final movies = context.read<MovieRepository>();
    final screenings = context.read<ScreeningRepository>();
    final movie = await movies.findById(widget.movieId);
    if (movie == null) return (movie: null, screenings: <Screening>[]);
    final page = await screenings.find(
      ListQuery(spec: kScreeningSpec, filters: {'movie': movie.id, 'period': 'upcoming'}, size: 50),
    );
    return (movie: movie, screenings: page.items);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Фильм',
      showBack: true,
      backPath: '/',
      body: FutureBuilder<_MoviePage>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Не удалось загрузить фильм: ${describeError(snapshot.error!)}',
              onRetry: () => setState(() {
                _loading = _load();
              }),
            );
          }
          final data = snapshot.data!;
          final movie = data.movie;
          if (movie == null) {
            return EmptyView(
              message: 'Фильм не найден',
              actionLabel: 'К афише',
              onAction: () => context.go('/'),
            );
          }
          return _content(context, movie, data.screenings);
        },
      ),
    );
  }

  Widget _content(BuildContext context, Movie movie, List<Screening> screenings) {
    final auth = context.watch<AuthNotifier>();
    final theme = Theme.of(context);
    final poster = movie.posterUrl;
    return DetailLayout(
      title: movie.title,
      actions: [
        if (auth.can(Permission.manageCatalog))
          FilledButton.tonalIcon(
            onPressed: () async {
              final changed = await context.push<bool>('/movies/${movie.id}/edit');
              if (changed == true && mounted) {
                setState(() {
                  _loading = _load();
                });
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Изменить'),
          ),
      ],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 110,
                height: 165,
                child: poster == null
                    ? PosterPlaceholder(title: movie.title)
                    : Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => PosterPlaceholder(title: movie.title),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final genre in movie.genreTitles) Chip(label: Text(genre)),
                  Chip(label: Text(movie.ageRating)),
                  Chip(label: Text('${movie.year}')),
                  Chip(label: Text(movie.durationText)),
                  if (movie.country.isNotEmpty) Chip(label: Text(movie.country)),
                ],
              ),
            ),
          ],
        ),
        if (movie.description.isNotEmpty)
          DetailField(label: 'Описание', child: Text(movie.description)),
        if (movie.directorNames.isNotEmpty)
          DetailField(label: 'Режиссёр', child: Text(movie.directorNames.join(', '))),
        if (movie.actorNames.isNotEmpty)
          DetailField(label: 'В ролях', child: Text(movie.actorNames.join(', '))),
        const Divider(height: 32),
        Text('Ближайшие сеансы', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (screenings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Ближайших сеансов нет.'),
          )
        else
          for (final screening in screenings) _ScreeningTile(screening: screening, auth: auth),
      ],
    );
  }
}

class _ScreeningTile extends StatelessWidget {
  const _ScreeningTile({required this.screening, required this.auth});

  final Screening screening;
  final AuthNotifier auth;

  @override
  Widget build(BuildContext context) {
    final hall = screening.hall;
    final price = hall == null
        ? screening.basePrice
        : ticketPrice(
            basePrice: screening.basePrice,
            hallFactor: hall.priceFactor,
            category: TicketCategory.full,
            startsAt: screening.startsAt,
          );
    final canSell = auth.can(Permission.buyTickets) || auth.can(Permission.useBoxOffice);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(formatCinemaShort(screening.startsAt)),
        subtitle: Text(
          '${hall == null ? 'Зал' : '${hall.name} (${hall.format})'} · ${screening.language}\n'
          'Полный билет: ${formatRub(price)}',
        ),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () => context.push('/screenings/${screening.id}'),
          child: Text(canSell ? 'Выбрать места' : 'Схема зала'),
        ),
      ),
    );
  }
}
