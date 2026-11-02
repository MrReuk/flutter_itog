import 'pricing.dart';

DateTime cinemaTime(DateTime moment) {
  return moment.toUtc().add(const Duration(hours: kCinemaUtcOffsetHours));
}

String _two(int value) => value.toString().padLeft(2, '0');

String formatCinemaDate(DateTime moment) {
  final t = cinemaTime(moment);
  return '${_two(t.day)}.${_two(t.month)}.${t.year}';
}

String formatCinemaClock(DateTime moment) {
  final t = cinemaTime(moment);
  return '${_two(t.hour)}:${_two(t.minute)}';
}

String formatCinemaDateTime(DateTime moment) {
  return '${formatCinemaDate(moment)} ${formatCinemaClock(moment)}';
}

const List<String> _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

String formatCinemaShort(DateTime moment) {
  final t = cinemaTime(moment);
  return '${_weekdays[t.weekday - 1]}, ${_two(t.day)}.${_two(t.month)} ${_two(t.hour)}:${_two(t.minute)}';
}

DateTime fromCinemaFields(DateTime fields) {
  return DateTime.utc(
    fields.year,
    fields.month,
    fields.day,
    fields.hour,
    fields.minute,
  ).subtract(const Duration(hours: kCinemaUtcOffsetHours));
}

String isoCinemaDate(DateTime moment) {
  final t = cinemaTime(moment);
  return '${t.year}-${_two(t.month)}-${_two(t.day)}';
}

String formatRub(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer ₽';
}
