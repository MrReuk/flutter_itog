import 'package:atrium_cinema/core/api_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

RequestOptions get _options => RequestOptions(path: '/collections/movies/records');

DioException _bad(int status, Object? body) => DioException(
  requestOptions: _options,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(requestOptions: _options, statusCode: status, data: body),
);

void main() {
  group('Коды ответа PocketBase превращаются в понятные исключения', () {
    test('400 с описанием полей — ошибка проверки данных', () {
      final error = mapHttpError(400, {
        'message': 'Failed to create record.',
        'data': {
          'title': {'code': 'validation_required', 'message': 'Cannot be blank.'},
        },
      });

      expect(error, isA<ValidationException>());
      expect((error as ValidationException).errors, {'title': 'Обязательное поле'});
    });

    test('400 без описания полей — отказ в доступе, а не ошибка формы', () {
      final error = mapHttpError(400, {'message': 'Failed to create record.', 'data': {}});

      expect(error, isA<ForbiddenException>());
      expect(error.message, contains('Failed to create record.'));
    });

    test('400 без тела', () {
      expect(mapHttpError(400, null).message, 'Сервер отклонил запрос.');
    });

    test('401, 403 и 404', () {
      expect(mapHttpError(401, {'message': 'Нужен вход.'}), isA<UnauthorizedException>());
      expect(mapHttpError(403, {'message': 'Not allowed.'}).message, contains('Not allowed.'));
      expect(mapHttpError(403, null), isA<ForbiddenException>());
      expect(mapHttpError(404, null), isA<NotFoundException>());
      expect(mapHttpError(404, null).message, 'Запись не найдена.');
    });

    test('409 сохраняет сообщения по полям', () {
      final error = mapHttpError(409, pbBody({'seat': 'Это место уже куплено.'}));

      expect(error, isA<ConflictException>());
      expect((error as ConflictException).errors['seat'], 'Это место уже куплено.');
    });

    test('422 тоже считается ошибкой проверки', () {
      expect(mapHttpError(422, null), isA<ValidationException>());
    });

    test('ошибки сервера и неизвестные коды', () {
      expect(mapHttpError(500, null), isA<ServerException>());
      expect(mapHttpError(503, null).message, 'Ошибка на сервере. Попробуйте позже.');
      expect(mapHttpError(418, null).message, 'Неизвестная ошибка (код 418).');
    });

    test('fieldErrors пропускает всё, что не похоже на описание поля', () {
      expect(fieldErrors(null), isEmpty);
      expect(fieldErrors('text'), isEmpty);
      expect(fieldErrors({'data': 5}), isEmpty);
      expect(
        fieldErrors({
          'data': {
            'a': 'строка',
            'b': {'code': 'x'},
            'c': {'message': 'Ошибка'},
          },
        }),
        {'c': 'Ошибка'},
      );
    });
  });

  group('Тексты ошибок полей', () {
    test('стандартные коды PocketBase переводятся на русский', () {
      final errors = fieldErrors({
        'data': {
          'email': {'code': 'validation_not_unique', 'message': 'Value must be unique.'},
          'title': {'code': 'validation_required', 'message': 'Cannot be blank.'},
        },
      });

      expect(errors['email'], 'Такое значение уже используется');
      expect(errors['title'], 'Обязательное поле');
    });

    test('свои правила сервера показываются с присланным текстом', () {
      final errors = fieldErrors({
        'data': {
          'startsAt': {'code': 'hall_busy', 'message': 'Зал занят в это время другим сеансом.'},
        },
      });

      expect(errors['startsAt'], 'Зал занят в это время другим сеансом.');
    });
  });

  group('Ошибки соединения', () {
    DioException typed(DioExceptionType type) => DioException(requestOptions: _options, type: type);

    test('нет соединения подсказывает запустить PocketBase', () {
      final error = mapDioError(typed(DioExceptionType.connectionError));

      expect(error, isA<NetworkException>());
      expect(error.message, contains('PocketBase'));
    });

    test('таймауты', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(mapDioError(typed(type)), isA<NetworkException>());
      }
    });

    test('отмена запроса — отдельное исключение', () {
      expect(mapDioError(typed(DioExceptionType.cancel)), isA<CancelledException>());
    });

    test('уже преобразованное исключение возвращается как есть', () {
      const original = ForbiddenException('нет прав');
      final dio = DioException(requestOptions: _options, error: original);

      expect(identical(mapDioError(dio), original), isTrue);
    });

    test('ответ сервера важнее типа ошибки', () {
      expect(mapDioError(_bad(409, null)), isA<ConflictException>());
    });
  });

  group('guard', () {
    test('переименовывает поля сервера в поля формы', () async {
      final future = guard<void>(
        () async => throw _bad(400, pbBody({'startsAt': 'Неверная дата.'})),
        fieldKeys: {'startsAt': 'start'},
      );

      await expectLater(
        future,
        throwsA(
          isA<ValidationException>().having((e) => e.errors, 'errors', {'start': 'Неверная дата.'}),
        ),
      );
    });

    test('переименовывает поля и в конфликте', () async {
      final future = guard<void>(
        () async => throw _bad(409, pbBody({'seat': 'Место занято.'})),
        fieldKeys: {'seat': 'place'},
      );

      await expectLater(
        future,
        throwsA(
          isA<ConflictException>().having((e) => e.errors, 'errors', {'place': 'Место занято.'}),
        ),
      );
    });

    test('неожиданный формат ответа не роняет приложение', () async {
      await expectLater(
        guard<void>(() async => throw const FormatException('bad')),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        guard<int>(() async => (null as dynamic) as int),
        throwsA(isA<ServerException>()),
      );
    });

    test('результат возвращается без изменений', () async {
      expect(await guard(() async => 42), 42);
    });
  });
}

Map<String, Object?> pbBody(Map<String, String> fields) => {
  'message': 'Ошибка',
  'data': {
    for (final e in fields.entries) e.key: {'code': 'x', 'message': e.value},
  },
};
