import 'package:dio/dio.dart';

import '../auth/app_user.dart';
import '../auth/role.dart';
import '../core/api_exceptions.dart';
import '../models/json_helpers.dart';
import '../models/list_query.dart';
import '../models/viewer_profile.dart';
import 'entity_repository.dart';
import 'pb_repository.dart';

abstract interface class UserRepository implements ListSource<AppUser> {
  Future<AppUser?> findById(String id);

  Future<AppUser> createUser({
    required String email,
    required String name,
    required Role role,
    required String password,
  });

  Future<AppUser> updateUser({required String id, required String name, required Role role});
}

class PbUserRepository extends PbRepository<AppUser> implements UserRepository {
  PbUserRepository({required super.dio, super.now}) : super(collection: 'users');

  @override
  String get defaultSort => 'name';

  @override
  AppUser fromJson(Map<String, dynamic> json) => AppUser.fromJson(json);

  @override
  Map<String, dynamic> toBody(AppUser item) => {'name': item.name, 'role': item.role.code};

  @override
  String idOf(AppUser item) => item.id;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()
      ..addIf(query.search, (q) => 'name ~ $q || email ~ $q')
      ..addIf(query.filter('role'), (q) => 'role = $q');
    return filter.build();
  }

  @override
  Future<AppUser> createUser({
    required String email,
    required String name,
    required Role role,
    required String password,
  }) {
    return guard(() async {
      final response = await dio.post<dynamic>(
        path,
        data: {
          'email': email.trim(),
          'name': name.trim(),
          'role': role.code,
          'password': password,
          'passwordConfirm': password,
          'emailVisibility': true,
        },
      );
      return AppUser.fromJson(jsonMap(response.data));
    });
  }

  @override
  Future<AppUser> updateUser({required String id, required String name, required Role role}) {
    return guard(() async {
      final response = await dio.patch<dynamic>(
        '$path/$id',
        data: {'name': name.trim(), 'role': role.code},
      );
      return AppUser.fromJson(jsonMap(response.data));
    });
  }
}

abstract interface class ProfileRepository {
  Future<ViewerProfile?> forUser(String userId);

  Future<ViewerProfile> save(ViewerProfile profile);
}

class PbProfileRepository implements ProfileRepository {
  PbProfileRepository({required this.dio});

  final Dio dio;

  static const String _path = '/collections/viewer_profiles/records';

  @override
  Future<ViewerProfile?> forUser(String userId) {
    return guard(() async {
      final response = await dio.get<dynamic>(
        _path,
        queryParameters: {'filter': 'user = ${pbQuote(userId)}', 'perPage': 1},
      );
      final items = jsonMap(response.data)['items'];
      if (items is! List || items.isEmpty) return null;
      return ViewerProfile.fromJson(jsonMap(items.first));
    });
  }

  @override
  Future<ViewerProfile> save(ViewerProfile profile) {
    return guard(() async {
      final response = await dio.patch<dynamic>('$_path/${profile.id}', data: profile.toBody());
      return ViewerProfile.fromJson(jsonMap(response.data));
    });
  }
}
