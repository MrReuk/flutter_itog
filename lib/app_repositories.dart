import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_api.dart';
import 'auth/auth_notifier.dart';
import 'auth/session_policy.dart';
import 'core/api_client.dart';
import 'repositories/repositories.dart';

class AppRepositories {
  AppRepositories({
    required this.auth,
    required this.genres,
    required this.people,
    required this.halls,
    required this.movies,
    required this.screenings,
    required this.orders,
    required this.tickets,
    required this.users,
    required this.profiles,
    this.cached = const [],
  });

  factory AppRepositories.fromDio({required Dio dio, required AuthNotifier auth}) {
    final genres = PbGenreRepository(dio: dio);
    final people = PbPersonRepository(dio: dio);
    final halls = PbHallRepository(dio: dio);
    final movies = PbMovieRepository(dio: dio);
    final screenings = PbScreeningRepository(dio: dio);
    final orders = PbOrderRepository(dio: dio);
    final tickets = PbTicketRepository(dio: dio);
    final users = PbUserRepository(dio: dio);
    return AppRepositories(
      auth: auth,
      genres: genres,
      people: people,
      halls: halls,
      movies: movies,
      screenings: screenings,
      orders: orders,
      tickets: tickets,
      users: users,
      profiles: PbProfileRepository(dio: dio),
      cached: [genres, people, halls, movies, screenings, orders, tickets, users],
    );
  }

  factory AppRepositories.connect({
    required SharedPreferences prefs,
    SessionPolicy policy = const SessionPolicy(),
  }) {
    final auth = AuthNotifier(prefs: prefs, api: AuthApi(buildAuthDio()), policy: policy);
    return AppRepositories.fromDio(
      dio: buildDio(auth: auth),
      auth: auth,
    );
  }

  final AuthNotifier auth;
  final GenreRepository genres;
  final PersonRepository people;
  final HallRepository halls;
  final MovieRepository movies;
  final ScreeningRepository screenings;
  final OrderRepository orders;
  final TicketRepository tickets;
  final UserRepository users;
  final ProfileRepository profiles;
  final List<CachedRepository> cached;

  void invalidateAll() {
    for (final repository in cached) {
      repository.invalidate();
    }
  }
}
