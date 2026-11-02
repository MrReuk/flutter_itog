import '../core/config.dart';

class SessionPolicy {
  const SessionPolicy({
    this.inactivity = const Duration(seconds: inactivitySeconds),
    this.warning = const Duration(seconds: inactivityWarningSeconds),
    this.maxDuration = const Duration(minutes: maxSessionMinutes),
  });

  final Duration inactivity;

  final Duration warning;

  final Duration maxDuration;

  Duration get warnAfter {
    final value = inactivity - warning;
    return value.isNegative ? Duration.zero : value;
  }
}
