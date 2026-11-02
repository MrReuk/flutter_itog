import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../models/movie.dart';
import '../state/load_status.dart';
import '../state/paged_list_notifier.dart';
import '../state/reference_notifier.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/list_toolbar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/responsive_grid.dart';
import '../widgets/state_views.dart';
import 'catalog_screens.dart';

class AfishaScreen extends StatefulWidget {
  const AfishaScreen({super.key, required this.query});

  final ListQuery query;

  @override
  State<AfishaScreen> createState() => _AfishaScreenState();
}

class _AfishaScreenState extends State<AfishaScreen> {
  PagedListNotifier<Movie> get _notifier => context.read<PagedListNotifier<Movie>>();

  void _go(ListQuery next) => context.go(next.toLocation('/'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.applyQuery(widget.query, force: true);
    });
  }

  @override
  void didUpdateWidget(AfishaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifier.applyQuery(widget.query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<PagedListNotifier<Movie>>();
    final refs = context.watch<ReferenceNotifier>();
    final q = widget.query;
    final result = notifier.result;

    Widget content;
    if (notifier.status == LoadStatus.error) {
      content = ErrorView(
        message: notifier.error ?? 'Неизвестная ошибка',
        onRetry: notifier.load,
        autoRetryEvery: notifier.offline ? kAutoRetryInterval : null,
      );
    } else if (result.items.isEmpty && notifier.status != LoadStatus.success) {
      content = const LoadingView();
    } else if (result.items.isEmpty) {
      content = EmptyView(
        message: 'Фильмы не найдены. Измените поиск или фильтры.',
        actionLabel: 'Сбросить условия',
        onAction: q.search.isNotEmpty || q.activeFilterCount > 0 ? () => _go(q.reset()) : null,
      );
    } else {
      content = Column(
        children: [
          if (notifier.status == LoadStatus.loading)
            const LinearProgressIndicator()
          else
            const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                ResponsiveGrid(
                  minTileWidth: 300,
                  children: [for (final movie in result.items) MovieCard(movie: movie)],
                ),
              ],
            ),
          ),
          PaginationBar(
            result: result,
            onPage: (page) => _go(q.copyWith(page: page)),
            onSize: (size) => _go(q.copyWith(size: size)),
          ),
        ],
      );
    }

    return AppScaffold(
      title: 'Афиша',
      body: Column(
        children: [
          ListToolbar(
            search: q.search,
            searchLabel: 'Поиск по названию или стране',
            onSearch: (text) => _go(q.copyWith(search: text)),
            activeFilterCount: q.activeFilterCount,
            initiallyOpen: q.activeFilterCount > 0,
            onReset: () => _go(q.reset()),
            filters: movieFilters(refs, q, _go),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = movie.posterUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/movies/${movie.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 84,
                  height: 126,
                  child: poster == null
                      ? PosterPlaceholder(title: movie.title)
                      : Image.network(
                          poster,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => PosterPlaceholder(title: movie.title),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie.genreTitles.join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text('${movie.year} · ${movie.durationText}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(movie.ageRating),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        TextButton(
                          onPressed: () => context.push('/movies/${movie.id}'),
                          child: const Text('Сеансы'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = title.trim().isEmpty ? '?' : title.trim().substring(0, 1).toUpperCase();
    return Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}
