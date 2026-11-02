import '../core/config.dart';
import 'json_helpers.dart';

const List<String> kAgeRatings = ['0+', '6+', '12+', '16+', '18+'];

class Movie {
  final String id;
  final String title;
  final String description;
  final int year;
  final int durationMin;
  final String ageRating;
  final String country;
  final String poster;
  final List<String> genreIds;
  final List<String> directorIds;
  final List<String> actorIds;

  final List<String> genreTitles;
  final List<String> directorNames;
  final List<String> actorNames;

  const Movie({
    required this.id,
    required this.title,
    this.description = '',
    required this.year,
    required this.durationMin,
    required this.ageRating,
    this.country = '',
    this.poster = '',
    this.genreIds = const [],
    this.directorIds = const [],
    this.actorIds = const [],
    this.genreTitles = const [],
    this.directorNames = const [],
    this.actorNames = const [],
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: jsonString(json['id']),
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      year: jsonInt(json['year']),
      durationMin: jsonInt(json['durationMin']),
      ageRating: jsonString(json['ageRating']),
      country: jsonString(json['country']),
      poster: jsonString(json['poster']),
      genreIds: jsonRefIds(json['genres']),
      directorIds: jsonRefIds(json['directors']),
      actorIds: jsonRefIds(json['actors']),
      genreTitles: [for (final g in expandedMany(json, 'genres')) jsonString(g['title'])],
      directorNames: [for (final p in expandedMany(json, 'directors')) jsonString(p['fullName'])],
      actorNames: [for (final p in expandedMany(json, 'actors')) jsonString(p['fullName'])],
    );
  }

  Map<String, dynamic> toBody() => {
    'title': title.trim(),
    'description': description.trim(),
    'year': year,
    'durationMin': durationMin,
    'ageRating': ageRating,
    'country': country.trim(),
    'genres': genreIds,
    'directors': directorIds,
    'actors': actorIds,
  };

  String? get posterUrl {
    if (poster.isEmpty) return null;
    return '$apiBaseUrl/files/movies/$id/$poster?thumb=200x300';
  }

  String get durationText => formatDuration(durationMin);
}

String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m мин';
  return m == 0 ? '$h ч' : '$h ч $m мин';
}
