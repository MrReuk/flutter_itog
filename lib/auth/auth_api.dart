import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/json_helpers.dart';
import 'app_user.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  static const String _users = '/collections/users';

  Future<AuthResult> login(String email, String password) {
    return guard(() async {
      final response = await _dio.post<dynamic>(
        '$_users/auth-with-password',
        data: {'identity': email.trim(), 'password': password},
      );
      final status = response.statusCode ?? 0;
      if (status == 400 || status == 401) {
        throw const UnauthorizedException('Неверная почта или пароль.');
      }
      return _result(_checked(response));
    });
  }

  Future<AuthResult> refresh(String token) {
    return guard(() async {
      final response = await _dio.post<dynamic>(
        '$_users/auth-refresh',
        options: Options(headers: {'Authorization': token}),
      );
      final status = response.statusCode ?? 0;
      if (status == 400 || status == 401 || status == 403 || status == 404) {
        throw const UnauthorizedException('Сессия истекла. Войдите снова.');
      }
      return _result(_checked(response));
    });
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) {
    return guard(() async {
      final response = await _dio.post<dynamic>(
        '$_users/records',
        data: {
          'email': email.trim(),
          'password': password,
          'passwordConfirm': password,
          'name': name.trim(),
          'role': 'viewer',
        },
      );
      return AppUser.fromJson(jsonMap(_checked(response)));
    });
  }

  Object? _checked(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status >= 400) throw mapHttpError(status, response.data);
    return response.data;
  }

  AuthResult _result(Object? data) {
    final map = jsonMap(data);
    final token = map['token'];
    if (token is! String || token.isEmpty) {
      throw const ServerException('Сервер не выдал токен.');
    }
    return AuthResult(token: token, user: AppUser.fromJson(jsonMap(map['record'])));
  }
}
