import 'package:dio/dio.dart';

import '../repositories/repository_exception.dart';

sealed class ApiException extends RepositoryException {
  const ApiException(super.message);
}

class NetworkException extends ApiException {
  const NetworkException([super.message = 'Сервер недоступен. Проверьте соединение.']);
}

class CancelledException extends ApiException {
  const CancelledException([super.message = 'Запрос отменён.']);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Недостаточно прав для этого действия.']);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  final Map<String, String> errors;

  const ConflictException(super.message, [this.errors = const {}]);
}

class ValidationException extends ApiException {
  final Map<String, String> errors;

  const ValidationException(super.message, this.errors);
}

class ServerException extends ApiException {
  const ServerException([super.message = 'Ошибка на сервере. Попробуйте позже.']);
}

const Map<String, String> kServerFieldMessages = {
  'validation_required': 'Обязательное поле',
  'validation_not_unique': 'Такое значение уже используется',
  'validation_is_email': 'Введите корректный адрес почты',
  'validation_invalid_email': 'Введите корректный адрес почты',
  'validation_min_text_constraint': 'Слишком короткое значение',
  'validation_max_text_constraint': 'Слишком длинное значение',
  'validation_length_out_of_range': 'Недопустимая длина значения',
  'validation_min_number_constraint': 'Значение меньше допустимого',
  'validation_max_number_constraint': 'Значение больше допустимого',
  'validation_values_mismatch': 'Значения не совпадают',
  'validation_invalid_format': 'Недопустимый формат значения',
  'validation_invalid_value': 'Недопустимое значение',
  'validation_invalid_date': 'Некорректная дата',
  'validation_invalid_or_missing_record': 'Выбранная запись не найдена',
};

Map<String, String> fieldErrors(dynamic body) {
  if (body is! Map || body['data'] is! Map) return const {};
  final result = <String, String>{};
  (body['data'] as Map).forEach((key, value) {
    if (value is Map && value['message'] != null) {
      result['$key'] = kServerFieldMessages['${value['code']}'] ?? '${value['message']}';
    }
  });
  return result;
}

String _sentence(String text) => text.endsWith('.') ? text : '$text.';

ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String) ? body['message'] as String : null;
  final errors = fieldErrors(body);

  return switch (status) {
    400 =>
      errors.isNotEmpty
          ? ValidationException('Проверьте заполнение полей.', errors)
          : ForbiddenException(
              message == null
                  ? 'Сервер отклонил запрос.'
                  : 'Сервер отклонил запрос. ${_sentence(message)}',
            ),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message == null
          ? 'Недостаточно прав для этого действия.'
          : 'Недостаточно прав для этого действия. ${_sentence(message)}',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.', errors),
    422 => ValidationException(message ?? 'Ошибка валидации', errors),
    _ => ServerException(
      message ??
          (status >= 500
              ? 'Ошибка на сервере. Попробуйте позже.'
              : 'Неизвестная ошибка (код $status).'),
    ),
  };
}

ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;

  final response = e.response;
  if (response != null) {
    return mapHttpError(response.statusCode ?? 0, response.data);
  }

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. Проверьте, что PocketBase запущен (pocketbase/start.bat).',
    ),
    DioExceptionType.badCertificate => const NetworkException(
      'Не удалось установить защищённое соединение.',
    ),
    DioExceptionType.cancel => const CancelledException(),
    _ => const ServerException(),
  };
}

ValidationException _renamed(ValidationException e, Map<String, String> keys) {
  if (keys.isEmpty) return e;
  return ValidationException(e.message, {
    for (final entry in e.errors.entries) (keys[entry.key] ?? entry.key): entry.value,
  });
}

ConflictException _renamedConflict(ConflictException e, Map<String, String> keys) {
  if (keys.isEmpty || e.errors.isEmpty) return e;
  return ConflictException(e.message, {
    for (final entry in e.errors.entries) (keys[entry.key] ?? entry.key): entry.value,
  });
}

Future<T> guard<T>(Future<T> Function() action, {Map<String, String> fieldKeys = const {}}) async {
  try {
    return await action();
  } on DioException catch (e) {
    final mapped = mapDioError(e);
    throw switch (mapped) {
      ValidationException() => _renamed(mapped, fieldKeys),
      ConflictException() => _renamedConflict(mapped, fieldKeys),
      _ => mapped,
    };
  } on ValidationException catch (e) {
    throw _renamed(e, fieldKeys);
  } on TypeError {
    throw const ServerException('Сервер вернул ответ в неожиданном формате.');
  } on FormatException {
    throw const ServerException('Сервер вернул ответ в неожиданном формате.');
  }
}
