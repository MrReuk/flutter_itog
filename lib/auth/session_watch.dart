import 'session_policy.dart';

enum SessionPhase { active, warning, inactive, expired }

typedef SessionStatus = ({SessionPhase phase, int secondsLeft});

class SessionWatch {
  SessionWatch({required this.policy, required DateTime startedAt, DateTime? lastActivity})
    : _startedAt = startedAt,
      _lastActivity = lastActivity ?? startedAt;

  final SessionPolicy policy;
  final DateTime _startedAt;
  DateTime _lastActivity;

  DateTime get lastActivity => _lastActivity;

  void activity(DateTime now) {
    _lastActivity = now;
  }

  int secondsLeft(DateTime now) {
    final left = policy.inactivity - now.difference(_lastActivity);
    if (left <= Duration.zero) return 0;
    return (left.inMilliseconds / 1000).ceil();
  }

  SessionStatus evaluate(DateTime now) {
    if (now.difference(_startedAt) >= policy.maxDuration) {
      return (phase: SessionPhase.expired, secondsLeft: 0);
    }
    final idle = now.difference(_lastActivity);
    if (idle >= policy.inactivity) {
      return (phase: SessionPhase.inactive, secondsLeft: 0);
    }
    if (idle >= policy.warnAfter) {
      return (phase: SessionPhase.warning, secondsLeft: secondsLeft(now));
    }
    return (phase: SessionPhase.active, secondsLeft: secondsLeft(now));
  }
}
