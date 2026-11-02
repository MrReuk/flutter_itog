typedef FieldCheck = String? Function(String value);

typedef TextValidator = String? Function(String value, Map<String, Object?> values);

typedef IdValidator = String? Function(String? value);

typedef IdsValidator = String? Function(List<String> value);

TextValidator checks(List<FieldCheck> list) {
  return (value, values) {
    for (final check in list) {
      final error = check(value);
      if (error != null) return error;
    }
    return null;
  };
}

FieldCheck notBlank([String message = 'Обязательное поле']) {
  return (value) => value.trim().isEmpty ? message : null;
}

FieldCheck minLength(int min) {
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return text.length < min ? 'Не короче $min символов' : null;
  };
}

FieldCheck maxLength(int max) {
  return (value) {
    final text = value.trim();
    return text.length > max ? 'Не длиннее $max символов' : null;
  };
}

FieldCheck namePattern() {
  final pattern = RegExp(r"^[A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё\s\-'.]*$");
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return pattern.hasMatch(text) ? null : 'Допустимы только буквы, пробел, точка и дефис';
  };
}

FieldCheck integerInRange(int min, int max) {
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null) return 'Введите целое число';
    if (number < min || number > max) return 'Допустимо от $min до $max';
    return null;
  };
}

FieldCheck positiveInteger({int max = 100000}) {
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null) return 'Введите целое число';
    if (number <= 0) return 'Число должно быть больше нуля';
    if (number > max) return 'Не больше $max';
    return null;
  };
}

FieldCheck nonNegativeInteger({int max = 100000}) {
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null) return 'Введите целое число';
    if (number < 0) return 'Число не может быть отрицательным';
    if (number > max) return 'Не больше $max';
    return null;
  };
}

FieldCheck emailFormat() {
  final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return pattern.hasMatch(text) ? null : 'Введите адрес в формате name@example.com';
  };
}

FieldCheck phoneFormat() {
  final allowed = RegExp(r'^\+?[0-9\s\-()]+$');
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if (!allowed.hasMatch(text)) {
      return 'Допустимы цифры, пробелы, скобки, дефис и «+»';
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'В номере должно быть от 10 до 15 цифр';
    }
    return null;
  };
}

DateTime? parseRuDate(String text) {
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(text.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String formatRuDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String? Function(String?) mustChoose(String message) {
  return (value) => value == null ? message : null;
}

String? Function(List<String>) mustChooseAtLeastOne(String message) {
  return (value) => value.isEmpty ? message : null;
}

DateTime? parseRuDateTime(String text) {
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  if (hour > 23 || minute > 59) return null;
  final date = DateTime(year, month, day, hour, minute);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String formatRuDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatRuDate(date)} $hour:$minute';
}

FieldCheck dateTimeFormat() {
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return parseRuDateTime(text) == null ? 'Введите дату и время в формате 31.12.2026 18:30' : null;
  };
}

FieldCheck dateFormat() {
  return (value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return parseRuDate(text) == null ? 'Введите дату в формате 31.12.2026' : null;
  };
}

FieldCheck decimalInRange(double min, double max) {
  return (value) {
    final text = value.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null) return 'Введите число';
    if (number < min || number > max) return 'Допустимо от $min до $max';
    return null;
  };
}
