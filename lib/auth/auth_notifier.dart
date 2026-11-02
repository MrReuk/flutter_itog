import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/auth_gateway.dart';
import '../core/config.dart';
import 'app_user.dart';
import 'auth_api.dart';
import 'jwt.dart';
import 'permissions.dart';
import 'role.dart';
import 'session_policy.dart';

enum SessionEnd {
  manual('Вы вышли из системы.'),
  inactivity('Сеанс завершён: долго не было действий.'),
  maxDuration('Сеанс завершён: исчерпана допустимая длительность сессии.'),
  tokenRejected('Сеанс завершён: срок действия токена истёк. Войдите снова.');

  const SessionEnd(this.message);

  final String message;
}

const String kAccessKey = 'auth_access_token';
const String kStartedKey = 'auth_session_started';
const String kActivityKey = 'auth_last_activity';
const String kUserKey = 'auth_user';

class AuthNotifier extends ChangeNotifier implements AuthGateway {
  AuthNotifier({
    required SharedPreferences prefs,
    required AuthApi api,
    this.policy = const SessionPolicy(),
    DateTime Function()? now,
  }) : _prefs = prefs,
       _api = api,
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final AuthApi _api;
  final DateTime Function() _now;
  final SessionPolicy policy;

  AppUser? _user;
  String? _accessToken;
  DateTime? _startedAt;
  SessionEnd? _lastEnd;
  bool _unverified = false;
  Future<void>? _refreshing;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  AppUser? get user => _user;

  @override
  String? get accessToken => _accessToken;

  @override
  bool get needsRefresh {
    final expiry = jwtExpiry(_accessToken);
    if (expiry == null) return false;
    return expiry.difference(_now()) < const Duration(seconds: tokenRefreshMarginSeconds);
  }

  bool get isAuthenticated => _user != null;

  Role? get role => _user?.role;

  bool get isUnverified => _unverified;

  SessionEnd? get lastEnd => _lastEnd;

  DateTime? get sessionStartedAt => _startedAt;

  DateTime? get sessionExpiresAt => _startedAt?.add(policy.maxDuration);

  bool has(Role role) => _user?.role == role;

  bool can(Permission permission) => roleCan(_user?.role, permission);

  void clearEndNotice() {
    if (_lastEnd == null) return;
    _lastEnd = null;
    notifyListeners();
  }

  Future<void> restore() async {
    final access = _prefs.getString(kAccessKey);
    if (access == null) {
      _unverified = false;
      notifyListeners();
      return;
    }

    _accessToken = access;
    _startedAt = _readTime(kStartedKey) ?? _now();

    final expired = _expiredReason();
    if (expired != null) {
      await logout(reason: expired);
      return;
    }

    try {
      _user = _readStoredUser();
      if (_user == null || needsRefresh) {
        await _applyRefresh(access);
      }
      _unverified = false;
    } on UnauthorizedException {
      await logout(reason: SessionEnd.tokenRejected);
      return;
    } on NetworkException {
      _unverified = true;
    } catch (_) {
      _unverified = true;
    }
    if (_user != null) {
      await _prefs.setInt(kActivityKey, _now().millisecondsSinceEpoch);
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _api.login(email, password);
    await _store(result);
    _startedAt = _now();
    _lastEnd = null;
    _unverified = false;
    await _prefs.setInt(kStartedKey, _startedAt!.millisecondsSinceEpoch);
    await _prefs.setInt(kActivityKey, _startedAt!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    await _api.register(email: email, password: password, name: name);
    await login(email, password);
  }

  Future<void> logout({SessionEnd reason = SessionEnd.manual}) async {
    final wasSignedIn = _user != null || _accessToken != null;
    _user = null;
    _accessToken = null;
    _startedAt = null;
    _unverified = false;
    _lastEnd = wasSignedIn ? reason : _lastEnd;
    await _prefs.remove(kAccessKey);
    await _prefs.remove(kStartedKey);
    await _prefs.remove(kActivityKey);
    await _prefs.remove(kUserKey);
    notifyListeners();
  }

  @override
  Future<void> refreshTokens() {
    return _refreshing ??= _refreshOnce().whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshOnce() async {
    final token = _accessToken ?? _prefs.getString(kAccessKey);
    if (token == null) {
      throw const UnauthorizedException('Сессия истекла. Войдите снова.');
    }
    await _applyRefresh(token);
  }

  Future<void> _applyRefresh(String token) async {
    final result = await _api.refresh(token);
    await _store(result);
    notifyListeners();
  }

  @override
  Future<void> sessionLost() async {
    if (_user == null && _accessToken == null) return;
    await logout(reason: SessionEnd.tokenRejected);
  }

  void touch() {
    if (_user == null) return;
    final now = _now();
    if (now.difference(_lastWrite) < const Duration(seconds: 1)) return;
    _lastWrite = now;
    _prefs.setInt(kActivityKey, now.millisecondsSinceEpoch);
  }

  Future<void> expire(SessionEnd reason) => logout(reason: reason);

  SessionEnd? _expiredReason() {
    final now = _now();
    final started = _startedAt;
    if (started != null && now.difference(started) >= policy.maxDuration) {
      return SessionEnd.maxDuration;
    }
    final activity = _readTime(kActivityKey);
    if (activity != null && now.difference(activity) >= policy.inactivity) {
      return SessionEnd.inactivity;
    }
    return null;
  }

  DateTime? _readTime(String key) {
    final value = _prefs.getInt(key);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> _store(AuthResult result) async {
    _accessToken = result.token;
    _user = result.user;
    await _prefs.setString(kAccessKey, result.token);
    await _prefs.setString(kUserKey, jsonEncode(result.user.toJson()));
  }

  AppUser? _readStoredUser() {
    final raw = _prefs.getString(kUserKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final user = AppUser.fromJson(data);
      return user.id.isNotEmpty && user.email.isNotEmpty ? user : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
