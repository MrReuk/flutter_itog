import '../core/api_exceptions.dart';
import '../models/json_helpers.dart';
import '../models/list_query.dart';
import '../models/pricing.dart';
import '../models/screening.dart';
import 'entity_repository.dart';
import 'pb_repository.dart';

typedef SeatPos = ({int row, int seat});

abstract interface class ScreeningRepository implements EntityRepository<Screening> {
  Future<List<SeatPos>> takenSeats(String screeningId);
}

({String from, String to}) dayRange(String isoDate) {
  final day = DateTime.tryParse(isoDate);
  if (day == null) return (from: '', to: '');
  const shift = Duration(hours: kCinemaUtcOffsetHours);
  final start = DateTime.utc(day.year, day.month, day.day).subtract(shift);
  final end = DateTime.utc(day.year, day.month, day.day + 1).subtract(shift);
  return (from: toPbDate(start), to: toPbDate(end));
}

String periodFilter(String field, String period, DateTime now) {
  final stamp = pbQuote(toPbDate(now));
  return switch (period) {
    'upcoming' => '$field >= $stamp',
    'past' => '$field < $stamp',
    _ => '',
  };
}

class PbScreeningRepository extends PbRepository<Screening> implements ScreeningRepository {
  PbScreeningRepository({required super.dio, super.now})
    : super(collection: 'screenings', expand: 'movie,hall');

  @override
  String get defaultSort => 'startsAt';

  @override
  Screening fromJson(Map<String, dynamic> json) => Screening.fromJson(json);

  @override
  Map<String, dynamic> toBody(Screening item) => item.toBody();

  @override
  String idOf(Screening item) => item.id;

  @override
  String sortFieldOf(String field) => field == 'movie' ? 'movie.title' : field;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()
      ..addIf(query.search, (q) => 'movie.title ~ $q')
      ..addIf(query.filter('movie'), (q) => 'movie = $q')
      ..addIf(query.filter('hall'), (q) => 'hall = $q')
      ..addIf(query.filter('language'), (q) => 'language = $q');
    final period = periodFilter('startsAt', query.filter('period'), clock());
    if (period.isNotEmpty) filter.add(period);
    final date = query.filter('date');
    if (date.isNotEmpty) {
      final range = dayRange(date);
      if (range.from.isNotEmpty) {
        filter.add('startsAt >= ${pbQuote(range.from)} && startsAt < ${pbQuote(range.to)}');
      }
    }
    return filter.build();
  }

  @override
  Future<List<SeatPos>> takenSeats(String screeningId) {
    return guard(() async {
      final response = await dio.get<dynamic>('/atrium/taken/$screeningId');
      final data = response.data;
      if (data is! List) throw const FormatException('Ожидался список мест');
      return [
        for (final item in data)
          (row: jsonInt(jsonMap(item)['row']), seat: jsonInt(jsonMap(item)['seat'])),
      ];
    });
  }
}
