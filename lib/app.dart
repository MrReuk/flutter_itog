import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_repositories.dart';
import 'auth/app_user.dart';
import 'auth/auth_notifier.dart';
import 'models/genre.dart';
import 'models/hall.dart';
import 'models/list_query.dart';
import 'models/list_specs.dart';
import 'models/movie.dart';
import 'models/order.dart';
import 'models/person.dart';
import 'models/screening.dart';
import 'models/ticket.dart';
import 'repositories/repositories.dart';
import 'router.dart';
import 'state/paged_list_notifier.dart';
import 'state/reference_notifier.dart';
import 'widgets/session_guard.dart';

const Color kBrandColor = Color(0xFF6D1B3A);

class AtriumApp extends StatefulWidget {
  const AtriumApp({super.key, required this.repositories, this.initialLocation = '/', this.clock});

  final AppRepositories repositories;
  final String initialLocation;

  final DateTime Function()? clock;

  @override
  State<AtriumApp> createState() => _AtriumAppState();
}

class _AtriumAppState extends State<AtriumApp> {
  late final AuthNotifier _auth = widget.repositories.auth;
  late final GoRouter _router = buildRouter(auth: _auth, initialLocation: widget.initialLocation);
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.user?.id;
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final id = _auth.user?.id;
    if (id == _userId) return;
    _userId = id;
    widget.repositories.invalidateAll();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repos = widget.repositories;

    PagedListNotifier<T> list<T>(ListSpec spec, ListSource<T> source, String Function(T) idOf) {
      return PagedListNotifier<T>(
        initialQuery: ListQuery.initial(spec),
        repository: source,
        idOf: idOf,
      );
    }

    return MultiProvider(
      key: ValueKey<String?>(_userId),
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: _auth),
        Provider<GenreRepository>.value(value: repos.genres),
        Provider<PersonRepository>.value(value: repos.people),
        Provider<HallRepository>.value(value: repos.halls),
        Provider<MovieRepository>.value(value: repos.movies),
        Provider<ScreeningRepository>.value(value: repos.screenings),
        Provider<OrderRepository>.value(value: repos.orders),
        Provider<TicketRepository>.value(value: repos.tickets),
        Provider<UserRepository>.value(value: repos.users),
        Provider<ProfileRepository>.value(value: repos.profiles),
        ChangeNotifierProvider<PagedListNotifier<Movie>>(
          create: (_) => list<Movie>(kMovieSpec, repos.movies, (m) => m.id),
        ),
        ChangeNotifierProvider<PagedListNotifier<Screening>>(
          create: (_) => list<Screening>(kScreeningSpec, repos.screenings, (s) => s.id),
        ),
        ChangeNotifierProvider<PagedListNotifier<Genre>>(
          create: (_) => list<Genre>(kGenreSpec, repos.genres, (g) => g.id),
        ),
        ChangeNotifierProvider<PagedListNotifier<Person>>(
          create: (_) => list<Person>(kPersonSpec, repos.people, (p) => p.id),
        ),
        ChangeNotifierProvider<PagedListNotifier<Hall>>(
          create: (_) => list<Hall>(kHallSpec, repos.halls, (h) => h.id),
        ),
        ChangeNotifierProvider<PagedListNotifier<Order>>(
          create: (_) => list<Order>(kOrderSpec, repos.orders, (o) => o.id),
        ),
        ChangeNotifierProvider<PagedListNotifier<Ticket>>(
          create: (_) => list<Ticket>(kTicketSpec, repos.tickets, (t) => t.id),
        ),
        ChangeNotifierProvider<PagedListNotifier<AppUser>>(
          create: (_) => list<AppUser>(kUserSpec, repos.users, (u) => u.id),
        ),
        ChangeNotifierProvider<ReferenceNotifier>(
          create: (_) => ReferenceNotifier(
            genres: repos.genres,
            people: repos.people,
            halls: repos.halls,
            movies: repos.movies,
          )..load(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Атриум',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kBrandColor),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kBrandColor, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        routerConfig: _router,
        builder: (context, child) =>
            SessionGuard(now: widget.clock, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
