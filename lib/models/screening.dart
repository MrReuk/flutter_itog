import 'hall.dart';
import 'json_helpers.dart';
import 'movie.dart';

const List<String> kLanguages = ['Дубляж', 'Оригинал, субтитры'];

class Screening {
  final String id;
  final String movieId;
  final String hallId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int basePrice;
  final String language;

  final Movie? movie;
  final Hall? hall;

  const Screening({
    required this.id,
    required this.movieId,
    required this.hallId,
    required this.startsAt,
    this.endsAt,
    required this.basePrice,
    required this.language,
    this.movie,
    this.hall,
  });

  factory Screening.fromJson(Map<String, dynamic> json) {
    final movie = expandedOne(json, 'movie');
    final hall = expandedOne(json, 'hall');
    return Screening(
      id: jsonString(json['id']),
      movieId: jsonRefId(json['movie']),
      hallId: jsonRefId(json['hall']),
      startsAt: jsonDate(json['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endsAt: jsonDate(json['endsAt']),
      basePrice: jsonInt(json['basePrice']),
      language: jsonString(json['language'], kLanguages.first),
      movie: movie.isEmpty ? null : Movie.fromJson(movie),
      hall: hall.isEmpty ? null : Hall.fromJson(hall),
    );
  }

  Map<String, dynamic> toBody() => {
    'movie': movieId,
    'hall': hallId,
    'startsAt': toPbDate(startsAt),
    'basePrice': basePrice,
    'language': language,
  };

  String get movieTitle => movie?.title ?? 'Фильм';
  String get hallName => hall?.name ?? 'Зал';
}
