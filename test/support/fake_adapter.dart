import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:atrium_cinema/core/api_client.dart';
import 'package:atrium_cinema/core/auth_gateway.dart';
import 'package:dio/dio.dart';

class FakeReply {
  const FakeReply(this.status, [this.body]);

  final int status;
  final Object? body;
}

typedef FakeHandler = FutureOr<FakeReply> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  FakeHandler handler;
  final List<RequestOptions> requests = [];

  final List<Map<String, dynamic>> sentHeaders = [];

  List<String> get calls => [for (final r in requests) '${r.method} ${r.path}'];

  RequestOptions last(String method, String pathStart) {
    return requests.lastWhere((r) => r.method == method && r.path.startsWith(pathStart));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    sentHeaders.add(Map<String, dynamic>.of(options.headers));
    final reply = await handler(options);
    final text = reply.body == null ? '' : jsonEncode(reply.body);
    return ResponseBody.fromString(
      text,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioException offline(RequestOptions options) => DioException(
  requestOptions: options,
  type: DioExceptionType.connectionError,
  message: 'offline',
);

Map<String, Object?> pbPage(
  List<Map<String, Object?>> items, {
  int? total,
  int page = 1,
  int perPage = 10,
}) {
  final count = total ?? items.length;
  return {
    'page': page,
    'perPage': perPage,
    'totalItems': count,
    'totalPages': count == 0 ? 1 : (count / perPage).ceil(),
    'items': items,
  };
}

Map<String, Object?> pbValidation(
  Map<String, String> fields, {
  String message = 'Failed to create record.',
}) {
  return {
    'status': 400,
    'message': message,
    'data': {
      for (final entry in fields.entries)
        entry.key: {'code': 'validation_error', 'message': entry.value},
    },
  };
}

Dio dioFor(FakeAdapter adapter, {AuthGateway? auth, List<Duration> retryDelays = const []}) {
  return buildDio(
    baseUrl: 'http://pb.test/api',
    auth: auth,
    adapter: adapter,
    retryDelays: retryDelays,
  );
}
