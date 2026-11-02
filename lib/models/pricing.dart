import 'ticket.dart';

const double kMorningFactor = 0.8;

const int kCinemaUtcOffsetHours = 3;

const int kBreakMinutes = 20;

bool isMorningScreening(DateTime startsAt) {
  final local = startsAt.toUtc().add(const Duration(hours: kCinemaUtcOffsetHours));
  return local.hour < 12;
}

int ticketPrice({
  required int basePrice,
  required double hallFactor,
  required TicketCategory category,
  required DateTime startsAt,
}) {
  final morning = isMorningScreening(startsAt) ? kMorningFactor : 1.0;
  return (basePrice * hallFactor * category.factor * morning).round();
}

DateTime screeningEnd(DateTime startsAt, int durationMin) {
  return startsAt.add(Duration(minutes: durationMin + kBreakMinutes));
}

bool intervalsOverlap(DateTime startA, DateTime endA, DateTime startB, DateTime endB) {
  return startA.isBefore(endB) && startB.isBefore(endA);
}
