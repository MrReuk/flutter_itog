import 'dart:convert';

import 'package:atrium_cinema/auth/jwt.dart';
import 'package:flutter_test/flutter_test.dart';

String _token(Map<String, Object?> payload) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.signature';
}

void main() {
  test('срок токена читается из поля exp', () {
    final token = _token({'exp': 1798761600, 'id': 'u1'});

    expect(jwtExpiry(token), DateTime.fromMillisecondsSinceEpoch(1798761600 * 1000));
  });

  test('нет токена, неверный формат или нет exp — срок неизвестен', () {
    expect(jwtExpiry(null), isNull);
    expect(jwtExpiry('abc'), isNull);
    expect(jwtExpiry('a.b.c'), isNull);
    expect(jwtExpiry(_token({'id': 'u1'})), isNull);
    expect(jwtExpiry(_token({'exp': 'завтра'})), isNull);
  });
}
