import 'package:atrium_cinema/app_repositories.dart';
import 'package:atrium_cinema/auth/app_user.dart';
import 'package:atrium_cinema/auth/auth_api.dart';
import 'package:atrium_cinema/auth/auth_notifier.dart';
import 'package:atrium_cinema/auth/role.dart';
import 'package:atrium_cinema/auth/session_policy.dart';
import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:atrium_cinema/models/format.dart';
import 'package:atrium_cinema/models/genre.dart';
import 'package:atrium_cinema/models/hall.dart';
import 'package:atrium_cinema/models/list_query.dart';
import 'package:atrium_cinema/models/movie.dart';
import 'package:atrium_cinema/models/order.dart';
import 'package:atrium_cinema/models/page_result.dart';
import 'package:atrium_cinema/models/person.dart';
import 'package:atrium_cinema/models/pricing.dart';
import 'package:atrium_cinema/models/screening.dart';
import 'package:atrium_cinema/models/ticket.dart';
import 'package:atrium_cinema/models/viewer_profile.dart';
import 'package:atrium_cinema/repositories/repositories.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, String> kTestPasswords = {
  'viewer@atrium.test': 'Viewer12345',
  'cashier@atrium.test': 'Cashier12345',
  'admin@atrium.test': 'Admin12345',
};

String emailOf(Role role) => '${role.code}@atrium.test';

class FakeAuthApi extends AuthApi {
  FakeAuthApi(this.users) : super(Dio());

  final List<AppUser> users;
  int logins = 0;
  int refreshes = 0;

  @override
  Future<AuthResult> login(String email, String password) async {
    logins++;
    final key = email.trim();
    for (final user in users) {
      if (user.email == key && kTestPasswords[key] == password) {
        return AuthResult(token: 'fake.token.${user.id}', user: user);
      }
    }
    throw const UnauthorizedException('Неверная почта или пароль.');
  }

  @override
  Future<AuthResult> refresh(String token) async {
    refreshes++;
    final id = token.split('.').last;
    for (final user in users) {
      if (user.id == id) return AuthResult(token: token, user: user);
    }
    throw const UnauthorizedException('Сессия истекла. Войдите снова.');
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    if (users.any((u) => u.email == email.trim())) {
      throw const ValidationException('Failed to create record.', {
        'email': 'Эта почта уже используется.',
      });
    }
    final user = AppUser(
      id: 'u${users.length + 1}',
      email: email.trim(),
      name: name.trim(),
      role: Role.viewer,
    );
    users.add(user);
    kTestPasswords[email.trim()] = password;
    return user;
  }
}

class TestData {
  TestData({DateTime? now}) : now = now ?? DateTime.now() {
    final today = DateTime.utc(this.now.year, this.now.month, this.now.day);
    genres = [
      const Genre(id: 'g1', title: 'Драма'),
      const Genre(id: 'g2', title: 'Комедия'),
      const Genre(id: 'g3', title: 'Триллер'),
    ];
    people = [
      const Person(id: 'p1', fullName: 'Алексей Громов', country: 'Россия'),
      const Person(id: 'p2', fullName: 'Мария Светлова', country: 'Россия'),
      const Person(id: 'p3', fullName: 'Ольга Рябина', country: 'Беларусь'),
    ];
    halls = [
      const Hall(id: 'h1', name: 'Зал 1', format: '2D', rows: 5, seatsPerRow: 8, priceFactor: 1),
      const Hall(id: 'h2', name: 'Зал VIP', format: 'VIP', rows: 3, seatsPerRow: 4, priceFactor: 2),
    ];
    movies = [
      const Movie(
        id: 'm1',
        title: 'Последний рейс',
        description: 'Пилот получает последний рейс.',
        year: 2025,
        durationMin: 118,
        ageRating: '16+',
        country: 'Россия',
        genreIds: ['g3', 'g1'],
        directorIds: ['p1'],
        actorIds: ['p2'],
        genreTitles: ['Триллер', 'Драма'],
        directorNames: ['Алексей Громов'],
        actorNames: ['Мария Светлова'],
      ),
      const Movie(
        id: 'm2',
        title: 'Лето в коммуналке',
        year: 2023,
        durationMin: 96,
        ageRating: '6+',
        country: 'Россия',
        genreIds: ['g2'],
        genreTitles: ['Комедия'],
      ),
      const Movie(
        id: 'm3',
        title: 'Тихая гавань',
        year: 2024,
        durationMin: 104,
        ageRating: '12+',
        country: 'Беларусь',
        genreIds: ['g1'],
        genreTitles: ['Драма'],
      ),
    ];
    screenings = [
      _screening('s1', 'm1', 'h1', today.add(const Duration(days: 1, hours: 15)), 400),
      _screening('s2', 'm2', 'h2', today.add(const Duration(days: 1, hours: 7)), 300),
      _screening('s3', 'm3', 'h1', today.add(const Duration(days: 2, hours: 15)), 350),
      _screening(
        's0',
        'm3',
        'h1',
        today.subtract(const Duration(days: 3)).add(const Duration(hours: 15)),
        350,
      ),
    ];
    users = [
      const AppUser(
        id: 'u1',
        email: 'viewer@atrium.test',
        name: 'Иван Зрителев',
        role: Role.viewer,
      ),
      const AppUser(
        id: 'u2',
        email: 'cashier@atrium.test',
        name: 'Мария Орлова',
        role: Role.cashier,
      ),
      const AppUser(id: 'u3', email: 'admin@atrium.test', name: 'Администратор', role: Role.admin),
    ];
  }

  final DateTime now;
  late List<Genre> genres;
  late List<Person> people;
  late List<Hall> halls;
  late List<Movie> movies;
  late List<Screening> screenings;
  late List<AppUser> users;

  Screening _screening(String id, String movieId, String hallId, DateTime start, int price) {
    final movie = movies.firstWhere((m) => m.id == movieId);
    final hall = halls.firstWhere((h) => h.id == hallId);
    return Screening(
      id: id,
      movieId: movieId,
      hallId: hallId,
      startsAt: start,
      endsAt: screeningEnd(start, movie.durationMin),
      basePrice: price,
      language: kLanguages.first,
      movie: movie,
      hall: hall,
    );
  }
}

class MemoryRepo<T> implements EntityRepository<T>, CachedRepository {
  MemoryRepo(
    this.rows, {
    required this.idOf,
    required this.matches,
    required this.compare,
    required this.withId,
  });

  final List<T> rows;
  final String Function(T item) idOf;
  final bool Function(T item, ListQuery query) matches;
  final int Function(T a, T b, String field) compare;
  final T Function(T item, String id) withId;

  Object? failNext;

  Object? saveError;

  final Set<String> protectedIds = {};

  Duration delay = Duration.zero;
  int findCalls = 0;
  ListQuery? lastQuery;
  int _next = 100;

  Future<void> _pause() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<PageResult<T>> find(ListQuery query) async {
    findCalls++;
    lastQuery = query;
    await _pause();
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
    final list = rows.where((r) => matches(r, query)).toList()
      ..sort((a, b) {
        final c = compare(a, b, query.sortField);
        return query.sortAscending ? c : -c;
      });
    return PageResult<T>.slice(list, page: query.page, size: query.size);
  }

  @override
  Future<List<T>> findAll() async => List<T>.of(rows);

  @override
  Future<T?> findById(String id) async {
    for (final row in rows) {
      if (idOf(row) == id) return row;
    }
    return null;
  }

  @override
  Future<T> create(T item) async {
    final error = saveError;
    if (error != null) {
      saveError = null;
      throw error;
    }
    final created = withId(item, 'n${_next++}');
    rows.add(created);
    return created;
  }

  @override
  Future<T> update(T item) async {
    final error = saveError;
    if (error != null) {
      saveError = null;
      throw error;
    }
    final index = rows.indexWhere((r) => idOf(r) == idOf(item));
    if (index < 0) throw const NotFoundException();
    rows[index] = item;
    return item;
  }

  @override
  Future<void> delete(String id) async {
    if (protectedIds.contains(id)) {
      throw const ConflictException('Запись используется в других данных.');
    }
    rows.removeWhere((r) => idOf(r) == id);
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      if (protectedIds.contains(id)) continue;
      rows.removeWhere((r) => idOf(r) == id);
      count++;
    }
    return count;
  }

  @override
  void invalidate() {}
}

bool _has(String text, String needle) => text.toLowerCase().contains(needle.toLowerCase());

int _cmp(Comparable<Object> a, Comparable<Object> b) => a.compareTo(b);

MemoryRepo<Genre> genreRepo(List<Genre> rows) => MemoryRepo<Genre>(
  rows,
  idOf: (g) => g.id,
  matches: (g, q) => q.search.isEmpty || _has(g.title, q.search),
  compare: (a, b, f) => _cmp(a.title, b.title),
  withId: (g, id) => Genre(id: id, title: g.title),
);

MemoryRepo<Person> personRepo(List<Person> rows) => MemoryRepo<Person>(
  rows,
  idOf: (p) => p.id,
  matches: (p, q) =>
      (q.search.isEmpty || _has(p.fullName, q.search)) &&
      (q.filter('country').isEmpty || p.country == q.filter('country')),
  compare: (a, b, f) => f == 'country' ? _cmp(a.country, b.country) : _cmp(a.fullName, b.fullName),
  withId: (p, id) =>
      Person(id: id, fullName: p.fullName, country: p.country, birthDate: p.birthDate),
);

MemoryRepo<Hall> hallRepo(List<Hall> rows) => MemoryRepo<Hall>(
  rows,
  idOf: (h) => h.id,
  matches: (h, q) =>
      (q.search.isEmpty || _has(h.name, q.search)) &&
      (q.filter('format').isEmpty || h.format == q.filter('format')),
  compare: (a, b, f) => switch (f) {
    'rows' => _cmp(a.rows, b.rows),
    'priceFactor' => _cmp(a.priceFactor, b.priceFactor),
    _ => _cmp(a.name, b.name),
  },
  withId: (h, id) => Hall(
    id: id,
    name: h.name,
    format: h.format,
    rows: h.rows,
    seatsPerRow: h.seatsPerRow,
    priceFactor: h.priceFactor,
  ),
);

MemoryRepo<Movie> movieRepo(List<Movie> rows) => MemoryRepo<Movie>(
  rows,
  idOf: (m) => m.id,
  matches: (m, q) {
    if (q.search.isNotEmpty && !_has(m.title, q.search) && !_has(m.country, q.search)) {
      return false;
    }
    final genre = q.filter('genre');
    if (genre.isNotEmpty && !m.genreIds.contains(genre)) return false;
    final age = q.filter('age');
    if (age.isNotEmpty && m.ageRating != age) return false;
    final from = int.tryParse(q.filter('yearFrom'));
    if (from != null && m.year < from) return false;
    final to = int.tryParse(q.filter('yearTo'));
    if (to != null && m.year > to) return false;
    return true;
  },
  compare: (a, b, f) => switch (f) {
    'year' => _cmp(a.year, b.year),
    'durationMin' => _cmp(a.durationMin, b.durationMin),
    _ => _cmp(a.title, b.title),
  },
  withId: (m, id) => Movie(
    id: id,
    title: m.title,
    description: m.description,
    year: m.year,
    durationMin: m.durationMin,
    ageRating: m.ageRating,
    country: m.country,
    genreIds: m.genreIds,
    directorIds: m.directorIds,
    actorIds: m.actorIds,
    genreTitles: m.genreTitles,
  ),
);

class FakeTicketRepo extends MemoryRepo<Ticket> implements TicketRepository {
  FakeTicketRepo(super.rows, {required this.now})
    : super(
        idOf: (t) => t.id,
        matches: (t, q) =>
            (q.search.isEmpty ||
                _has(t.id, q.search) ||
                _has(t.screening?.movieTitle ?? '', q.search)) &&
            (q.filter('status').isEmpty || t.status.code == q.filter('status')) &&
            (q.filter('category').isEmpty || t.category.code == q.filter('category')),
        compare: (a, b, f) => f == 'price' ? _cmp(a.price, b.price) : _cmp(a.id, b.id),
        withId: (t, id) => t,
      );

  final DateTime now;

  bool isTaken(String screeningId, int row, int seat) {
    return rows.any(
      (t) =>
          t.screeningId == screeningId &&
          t.row == row &&
          t.seat == seat &&
          t.status != TicketStatus.returned,
    );
  }

  @override
  Future<Ticket> setStatus(String id, TicketStatus status) async {
    final index = rows.indexWhere((t) => t.id == id);
    if (index < 0) throw const NotFoundException();
    final old = rows[index];
    rows[index] = Ticket(
      id: old.id,
      orderId: old.orderId,
      screeningId: old.screeningId,
      row: old.row,
      seat: old.seat,
      category: old.category,
      price: old.price,
      status: status,
      screening: old.screening,
    );
    return rows[index];
  }
}

class FakeOrderRepo extends MemoryRepo<Order> implements OrderRepository {
  FakeOrderRepo(super.rows, {required this.tickets, required this.screenings})
    : super(
        idOf: (o) => o.id,
        matches: (o, q) =>
            (q.search.isEmpty || _has(o.customerName, q.search) || _has(o.id, q.search)) &&
            (q.filter('status').isEmpty || o.status.code == q.filter('status')) &&
            switch (q.filter('channel')) {
              'box' => o.isBoxOffice,
              'online' => !o.isBoxOffice,
              _ => true,
            },
        compare: (a, b, f) => f == 'total' ? _cmp(a.total, b.total) : _cmp(a.id, b.id),
        withId: (o, id) => o,
      );

  final FakeTicketRepo tickets;
  final List<Screening> screenings;
  String? cashierId;

  @override
  Future<List<Ticket>> ticketsOf(String orderId) async {
    return [
      for (final t in tickets.rows)
        if (t.orderId == orderId) t,
    ];
  }

  @override
  Future<CheckoutResult> checkout({
    required String screeningId,
    String? customerId,
    required List<SeatChoice> seats,
  }) async {
    final screening = screenings.firstWhere((s) => s.id == screeningId);
    final hall = screening.hall!;
    final orderId = 'o${_orderNumber++}';
    final created = <Ticket>[];
    for (final seat in seats) {
      if (tickets.isTaken(screeningId, seat.row, seat.seat)) {
        for (final t in created) {
          await tickets.setStatus(t.id, TicketStatus.returned);
        }
        throw const ConflictException('Место уже занято', {'seat': 'Это место уже куплено.'});
      }
      final ticket = Ticket(
        id: 't${_ticketNumber++}',
        orderId: orderId,
        screeningId: screeningId,
        row: seat.row,
        seat: seat.seat,
        category: seat.category,
        price: ticketPrice(
          basePrice: screening.basePrice,
          hallFactor: hall.priceFactor,
          category: seat.category,
          startsAt: screening.startsAt,
        ),
        status: TicketStatus.sold,
        screening: screening,
      );
      tickets.rows.add(ticket);
      created.add(ticket);
    }
    final order = Order(
      id: orderId,
      screeningId: screeningId,
      customerId: customerId ?? '',
      cashierId: cashierId ?? '',
      status: OrderStatus.paid,
      total: created.fold(0, (sum, t) => sum + t.price),
      created: DateTime.now(),
      screening: screening,
      customerName: customerId == null ? '' : 'Иван Зрителев',
    );
    rows.add(order);
    return CheckoutResult(order: order, tickets: created);
  }

  int _orderNumber = 500;
  int _ticketNumber = 900;

  @override
  Future<void> refund(String orderId) async {
    for (final t in await ticketsOf(orderId)) {
      if (t.status == TicketStatus.sold) {
        await tickets.setStatus(t.id, TicketStatus.returned);
      }
    }
    final index = rows.indexWhere((o) => o.id == orderId);
    final old = rows[index];
    rows[index] = Order(
      id: old.id,
      screeningId: old.screeningId,
      customerId: old.customerId,
      cashierId: old.cashierId,
      status: OrderStatus.refunded,
      total: 0,
      created: old.created,
      screening: old.screening,
      customerName: old.customerName,
    );
  }
}

class FakeScreeningRepo extends MemoryRepo<Screening> implements ScreeningRepository {
  FakeScreeningRepo(super.rows, {required this.tickets, required this.catalog, required this.now})
    : super(
        idOf: (s) => s.id,
        matches: (s, q) {
          if (q.search.isNotEmpty && !_has(s.movieTitle, q.search)) {
            return false;
          }
          if (q.filter('movie').isNotEmpty && s.movieId != q.filter('movie')) {
            return false;
          }
          if (q.filter('hall').isNotEmpty && s.hallId != q.filter('hall')) {
            return false;
          }
          if (q.filter('language').isNotEmpty && s.language != q.filter('language')) {
            return false;
          }
          switch (q.filter('period')) {
            case 'upcoming':
              if (s.startsAt.isBefore(now)) return false;
            case 'past':
              if (!s.startsAt.isBefore(now)) return false;
          }
          final date = q.filter('date');
          if (date.isNotEmpty) {
            final range = dayRange(date);
            final start = toPbDateText(s.startsAt);
            if (start.compareTo(range.from) < 0 || start.compareTo(range.to) >= 0) {
              return false;
            }
          }
          return true;
        },
        compare: (a, b, f) => switch (f) {
          'basePrice' => _cmp(a.basePrice, b.basePrice),
          'movie' => _cmp(a.movieTitle, b.movieTitle),
          _ => _cmp(a.startsAt, b.startsAt),
        },
        withId: (s, id) => s,
      );

  final FakeTicketRepo tickets;
  final TestData catalog;
  final DateTime now;

  final Set<SeatPos> foreignTaken = {};

  Screening _complete(Screening s, String id) {
    final movie = catalog.movies.firstWhere((m) => m.id == s.movieId);
    final hall = catalog.halls.firstWhere((h) => h.id == s.hallId);
    return Screening(
      id: id,
      movieId: s.movieId,
      hallId: s.hallId,
      startsAt: s.startsAt,
      endsAt: screeningEnd(s.startsAt, movie.durationMin),
      basePrice: s.basePrice,
      language: s.language,
      movie: movie,
      hall: hall,
    );
  }

  void _checkOverlap(Screening s, String id) {
    final movie = catalog.movies.firstWhere((m) => m.id == s.movieId);
    final end = screeningEnd(s.startsAt, movie.durationMin);
    for (final other in rows) {
      if (other.id == id || other.hallId != s.hallId) continue;
      if (intervalsOverlap(s.startsAt, end, other.startsAt, other.endsAt ?? other.startsAt)) {
        throw const ConflictException('В это время зал занят другим сеансом', {
          'startsAt': 'Зал занят в это время другим сеансом.',
        });
      }
    }
  }

  @override
  Future<Screening> create(Screening item) async {
    _checkOverlap(item, '');
    return super.create(_complete(item, 'n${rows.length + 100}'));
  }

  @override
  Future<Screening> update(Screening item) async {
    _checkOverlap(item, item.id);
    return super.update(_complete(item, item.id));
  }

  @override
  Future<List<SeatPos>> takenSeats(String screeningId) async {
    return [
      for (final t in tickets.rows)
        if (t.screeningId == screeningId && t.status != TicketStatus.returned)
          (row: t.row, seat: t.seat),
      ...foreignTaken,
    ];
  }
}

String toPbDateText(DateTime value) => value.toUtc().toIso8601String().replaceFirst('T', ' ');

class FakeUserRepo extends MemoryRepo<AppUser> implements UserRepository {
  FakeUserRepo(super.rows)
    : super(
        idOf: (u) => u.id,
        matches: (u, q) =>
            (q.search.isEmpty || _has(u.name, q.search) || _has(u.email, q.search)) &&
            (q.filter('role').isEmpty || u.role.code == q.filter('role')),
        compare: (a, b, f) => switch (f) {
          'email' => _cmp(a.email, b.email),
          'role' => _cmp(a.role.code, b.role.code),
          _ => _cmp(a.name, b.name),
        },
        withId: (u, id) => u,
      );

  @override
  Future<AppUser> createUser({
    required String email,
    required String name,
    required Role role,
    required String password,
  }) async {
    if (rows.any((u) => u.email == email.trim())) {
      throw const ValidationException('Failed to create record.', {
        'email': 'Эта почта уже используется.',
      });
    }
    final user = AppUser(id: 'n${rows.length + 100}', email: email.trim(), name: name, role: role);
    rows.add(user);
    return user;
  }

  @override
  Future<AppUser> updateUser({required String id, required String name, required Role role}) async {
    final index = rows.indexWhere((u) => u.id == id);
    if (index < 0) throw const NotFoundException();
    final old = rows[index];
    rows[index] = AppUser(id: id, email: old.email, name: name, role: role);
    return rows[index];
  }
}

class FakeProfileRepo implements ProfileRepository {
  final Map<String, ViewerProfile> byUser = {
    'u1': const ViewerProfile(id: 'vp1', userId: 'u1', phone: '+7 900 123-45-67'),
  };
  ViewerProfile? lastSaved;

  @override
  Future<ViewerProfile?> forUser(String userId) async => byUser[userId];

  @override
  Future<ViewerProfile> save(ViewerProfile profile) async {
    lastSaved = profile;
    byUser[profile.userId] = profile;
    return profile;
  }
}

class TestWorld {
  TestWorld._(
    this.data,
    this.repos,
    this.genres,
    this.people,
    this.halls,
    this.movies,
    this.screenings,
    this.orders,
    this.tickets,
    this.users,
    this.profiles,
  );

  final TestData data;
  final AppRepositories repos;
  final MemoryRepo<Genre> genres;
  final MemoryRepo<Person> people;
  final MemoryRepo<Hall> halls;
  final MemoryRepo<Movie> movies;
  final FakeScreeningRepo screenings;
  final FakeOrderRepo orders;
  final FakeTicketRepo tickets;
  final FakeUserRepo users;
  final FakeProfileRepo profiles;

  AuthNotifier get auth => repos.auth;

  static Future<TestWorld> create({Role? role = Role.admin, DateTime Function()? now}) async {
    final data = TestData();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeAuthApi(List<AppUser>.of(data.users));
    final auth = AuthNotifier(prefs: prefs, api: api, policy: const SessionPolicy(), now: now);

    final tickets = FakeTicketRepo([], now: data.now);
    final screeningRepo = FakeScreeningRepo(
      data.screenings,
      tickets: tickets,
      catalog: data,
      now: data.now,
    );
    final first = data.screenings.first;
    tickets.rows.add(
      Ticket(
        id: 't1',
        orderId: 'o1',
        screeningId: first.id,
        row: 2,
        seat: 3,
        category: TicketCategory.full,
        price: 400,
        status: TicketStatus.sold,
        screening: first,
      ),
    );
    final orders = FakeOrderRepo(
      [
        Order(
          id: 'o1',
          screeningId: first.id,
          customerId: 'u1',
          status: OrderStatus.paid,
          total: 400,
          created: data.now,
          screening: first,
          customerName: 'Иван Зрителев',
        ),
      ],
      tickets: tickets,
      screenings: data.screenings,
    );
    final genres = genreRepo(data.genres);
    final people = personRepo(data.people);
    final halls = hallRepo(data.halls);
    final movies = movieRepo(data.movies);
    final users = FakeUserRepo(List<AppUser>.of(data.users));
    final profiles = FakeProfileRepo();

    final repos = AppRepositories(
      auth: auth,
      genres: genres,
      people: people,
      halls: halls,
      movies: movies,
      screenings: screeningRepo,
      orders: orders,
      tickets: tickets,
      users: users,
      profiles: profiles,
    );
    final world = TestWorld._(
      data,
      repos,
      genres,
      people,
      halls,
      movies,
      screeningRepo,
      orders,
      tickets,
      users,
      profiles,
    );
    if (role != null) {
      orders.cashierId = role == Role.cashier ? 'u2' : null;
      await auth.login(emailOf(role), kTestPasswords[emailOf(role)]!);
    }
    return world;
  }
}

String shown(DateTime moment) => formatCinemaShort(moment);
