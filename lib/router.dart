import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_notifier.dart';
import 'auth/route_access.dart';
import 'models/list_query.dart';
import 'models/list_specs.dart';
import 'screens/afisha_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/catalog_screens.dart';
import 'screens/forbidden_screen.dart';
import 'screens/login_screen.dart';
import 'screens/movie_detail_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/offline_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/sales_screens.dart';
import 'screens/screening_screens.dart';
import 'screens/user_screens.dart';

ListQuery _query(ListSpec spec, GoRouterState state) {
  return ListQuery.fromParams(spec, state.uri.queryParameters);
}

GoRoute _section({
  required String path,
  required Widget Function(GoRouterState state) list,
  required Widget Function(String? id) form,
  Widget Function(String id)? detail,
}) {
  return GoRoute(
    path: path,
    builder: (context, state) => list(state),
    routes: [
      GoRoute(path: 'new', builder: (context, state) => form(null)),
      GoRoute(path: ':id/edit', builder: (context, state) => form(state.pathParameters['id'])),
      if (detail != null)
        GoRoute(path: ':id', builder: (context, state) => detail(state.pathParameters['id']!)),
    ],
  );
}

String? guardLocation(AuthNotifier auth, GoRouterState state) {
  final path = state.uri.path;
  final full = state.uri.toString();

  if (auth.isUnverified) return path == '/offline' ? null : '/offline';

  if (!auth.isAuthenticated) {
    if (isPublicPath(path)) return null;
    final target = safeReturnTo(full);
    if (target == null || target == '/') return '/login';
    return '/login?from=${Uri.encodeComponent(target)}';
  }

  if (path == '/offline') return '/';
  if (isPublicPath(path)) {
    return safeReturnTo(state.uri.queryParameters['from']) ?? '/';
  }

  final needed = requiredPermission(full);
  if (needed != null && !auth.can(needed)) {
    return '/forbidden?path=${Uri.encodeComponent(full)}';
  }
  return null;
}

GoRouter buildRouter({required AuthNotifier auth, String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) => guardLocation(auth, state),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => AfishaScreen(query: _query(kMovieSpec, state)),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/offline', builder: (context, state) => const OfflineScreen()),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => ForbiddenScreen(attempted: state.uri.queryParameters['path']),
      ),
      _section(
        path: '/movies',
        list: (state) => MovieListScreen(query: _query(kMovieSpec, state)),
        form: (id) => MovieFormScreen(movieId: id),
        detail: (id) => MovieDetailScreen(movieId: id),
      ),
      _section(
        path: '/screenings',
        list: (state) => ScreeningListScreen(query: _query(kScreeningSpec, state)),
        form: (id) => ScreeningFormScreen(screeningId: id),
        detail: (id) => BookingScreen(screeningId: id),
      ),
      _section(
        path: '/genres',
        list: (state) => GenreListScreen(query: _query(kGenreSpec, state)),
        form: (id) => GenreFormScreen(genreId: id),
      ),
      _section(
        path: '/people',
        list: (state) => PersonListScreen(query: _query(kPersonSpec, state)),
        form: (id) => PersonFormScreen(personId: id),
      ),
      _section(
        path: '/halls',
        list: (state) => HallListScreen(query: _query(kHallSpec, state)),
        form: (id) => HallFormScreen(hallId: id),
      ),
      GoRoute(
        path: '/box-office',
        builder: (context, state) => ScreeningListScreen(
          query: _query(kScreeningSpec, state),
          boxOffice: true,
          path: '/box-office',
        ),
      ),
      GoRoute(
        path: '/my/tickets',
        builder: (context, state) =>
            TicketListScreen(query: _query(kTicketSpec, state), mine: true),
      ),
      GoRoute(path: '/my/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => TicketListScreen(query: _query(kTicketSpec, state)),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => OrderListScreen(query: _query(kOrderSpec, state)),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => UserListScreen(query: _query(kUserSpec, state)),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const UserFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) => UserFormScreen(userId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => NotFoundScreen(location: state.uri.toString()),
  );
}
