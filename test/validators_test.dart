import 'package:atrium_cinema/auth/password_rules.dart';
import 'package:atrium_cinema/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Текстовые проверки', () {
    test('notBlank отвергает пустую строку и пробелы', () {
      expect(notBlank()(''), isNotNull);
      expect(notBlank()('   '), isNotNull);
      expect(notBlank()('а'), isNull);
    });

    test('длина считается без пробелов по краям', () {
      expect(minLength(3)('  аб '), isNotNull);
      expect(minLength(3)('абв'), isNull);
      expect(maxLength(5)('шестьсм'), isNotNull);
      expect(maxLength(5)('пять '), isNull);
    });

    test('пустое значение не нарушает minLength: за пустоту отвечает notBlank', () {
      expect(minLength(3)(''), isNull);
    });

    test('имя: буквы, пробел, точка и дефис', () {
      expect(namePattern()('Анна-Мария И.'), isNull);
      expect(namePattern()('Anna Smith'), isNull);
      expect(namePattern()('Иван2'), isNotNull);
      expect(namePattern()('<script>'), isNotNull);
    });

    test('checks возвращает первую найденную ошибку', () {
      final validator = checks([notBlank(), minLength(3)]);

      expect(validator('', const {}), 'Обязательное поле');
      expect(validator('аб', const {}), 'Не короче 3 символов');
      expect(validator('абв', const {}), isNull);
    });
  });

  group('Числа', () {
    test('целое в диапазоне', () {
      final check = integerInRange(1, 20);

      expect(check('1'), isNull);
      expect(check('20'), isNull);
      expect(check('0'), 'Допустимо от 1 до 20');
      expect(check('21'), 'Допустимо от 1 до 20');
      expect(check('2,5'), 'Введите целое число');
      expect(check('abc'), 'Введите целое число');
      expect(check(''), isNull);
    });

    test('положительное и неотрицательное целое', () {
      expect(positiveInteger()('5'), isNull);
      expect(positiveInteger()('0'), isNotNull);
      expect(positiveInteger(max: 10)('11'), 'Не больше 10');
      expect(nonNegativeInteger()('0'), isNull);
      expect(nonNegativeInteger()('-1'), isNotNull);
      expect(nonNegativeInteger()('abc'), 'Введите целое число');
    });

    test('дробное в диапазоне принимает запятую', () {
      final check = decimalInRange(0.5, 3);

      expect(check('1,5'), isNull);
      expect(check('0.5'), isNull);
      expect(check('0,4'), isNotNull);
      expect(check('3,1'), isNotNull);
      expect(check('x'), 'Введите число');
    });
  });

  group('Даты', () {
    test('дата «дд.мм.гггг»', () {
      expect(parseRuDate('05.11.2026'), DateTime(2026, 11, 5));
      expect(parseRuDate('31.02.2026'), isNull);
      expect(parseRuDate('2026-11-05'), isNull);
      expect(dateFormat()('5.11.2026'), isNotNull);
      expect(dateFormat()(''), isNull);
    });

    test('дата и время «дд.мм.гггг чч:мм»', () {
      expect(parseRuDateTime('05.11.2026 18:30'), DateTime(2026, 11, 5, 18, 30));
      expect(parseRuDateTime('05.11.2026 9:05'), DateTime(2026, 11, 5, 9, 5));
      expect(parseRuDateTime('05.11.2026 24:00'), isNull);
      expect(parseRuDateTime('05.11.2026 12:60'), isNull);
      expect(parseRuDateTime('05.11.2026'), isNull);
      expect(dateTimeFormat()('вечером'), isNotNull);
    });

    test('форматирование даты и времени', () {
      expect(formatRuDate(DateTime(2026, 1, 9)), '09.01.2026');
      expect(formatRuDateTime(DateTime(2026, 1, 9, 7, 5)), '09.01.2026 07:05');
    });
  });

  group('Почта и телефон', () {
    test('почта', () {
      expect(emailFormat()('viewer@atrium.test'), isNull);
      expect(emailFormat()('viewer@'), isNotNull);
      expect(emailFormat()('viewer atrium.test'), isNotNull);
    });

    test('телефон: от 10 до 15 цифр', () {
      expect(phoneFormat()('+7 900 123-45-67'), isNull);
      expect(phoneFormat()('12345'), isNotNull);
      expect(phoneFormat()('+7 (900) abc'), isNotNull);
      expect(phoneFormat()(''), isNull);
    });
  });

  group('Пароль', () {
    test('сообщение называет первое невыполненное правило', () {
      expect(passwordError(''), 'Введите пароль');
      expect(passwordError('Ab1!'), contains('не короче 8'));
      expect(passwordError('Abcdefgh!'), contains('цифру'));
      expect(passwordError('Abcdefgh1'), contains('специальный'));
      expect(passwordError('Abcdefg1!'), isNull);
    });
  });

  group('Выбор значения', () {
    test('обязательный выбор', () {
      expect(mustChoose('Выберите роль')(null), 'Выберите роль');
      expect(mustChoose('Выберите роль')('admin'), isNull);
      expect(mustChooseAtLeastOne('Нужен жанр')(const []), 'Нужен жанр');
      expect(mustChooseAtLeastOne('Нужен жанр')(const ['g1']), isNull);
    });
  });
}
