import 'permissions.dart';

Permission? requiredPermission(String location) {
  final path = Uri.parse(location).path;
  final segments = [
    for (final s in path.split('/'))
      if (s.isNotEmpty) s,
  ];
  if (segments.isEmpty) return null;

  final writes = segments.length >= 2 && (segments[1] == 'new' || segments.last == 'edit');

  switch (segments.first) {
    case 'movies':
    case 'screenings':
    case 'genres':
    case 'people':
    case 'halls':
      final reference = {'genres', 'people', 'halls'}.contains(segments.first);
      if (writes || reference) return Permission.manageCatalog;
      return Permission.browse;
    case 'my':
      final section = segments.length >= 2 ? segments[1] : '';
      return section == 'profile' ? Permission.editProfile : Permission.viewOwnTickets;
    case 'box-office':
      return Permission.useBoxOffice;
    case 'orders':
      return Permission.viewOrders;
    case 'tickets':
      return Permission.checkTickets;
    case 'admin':
      return Permission.manageUsers;
  }
  return null;
}

const Set<String> _publicPaths = {'/login', '/register'};

bool isPublicPath(String path) => _publicPaths.contains(path);

String? safeReturnTo(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/') || from.startsWith('//') || from.contains('\\')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null) return null;
  if (isPublicPath(path) || path == '/offline' || path == '/forbidden') {
    return null;
  }
  return from;
}
