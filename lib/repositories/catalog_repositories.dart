import '../models/genre.dart';
import '../models/hall.dart';
import '../models/json_helpers.dart';
import '../models/list_query.dart';
import '../models/movie.dart';
import '../models/person.dart';
import 'entity_repository.dart';
import 'pb_repository.dart';

typedef GenreRepository = EntityRepository<Genre>;
typedef PersonRepository = EntityRepository<Person>;
typedef HallRepository = EntityRepository<Hall>;
typedef MovieRepository = EntityRepository<Movie>;

class PbGenreRepository extends PbRepository<Genre> {
  PbGenreRepository({required super.dio, super.now}) : super(collection: 'genres', cacheAll: true);

  @override
  String get defaultSort => 'title';

  @override
  Genre fromJson(Map<String, dynamic> json) => Genre.fromJson(json);

  @override
  Map<String, dynamic> toBody(Genre item) => item.toBody();

  @override
  String idOf(Genre item) => item.id;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()..addIf(query.search, (q) => 'title ~ $q');
    return filter.build();
  }
}

class PbPersonRepository extends PbRepository<Person> {
  PbPersonRepository({required super.dio, super.now}) : super(collection: 'people', cacheAll: true);

  @override
  String get defaultSort => 'fullName';

  @override
  Person fromJson(Map<String, dynamic> json) => Person.fromJson(json);

  @override
  Map<String, dynamic> toBody(Person item) => item.toBody();

  @override
  String idOf(Person item) => item.id;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()
      ..addIf(query.search, (q) => 'fullName ~ $q')
      ..addIf(query.filter('country'), (q) => 'country = $q');
    return filter.build();
  }
}

class PbHallRepository extends PbRepository<Hall> {
  PbHallRepository({required super.dio, super.now}) : super(collection: 'halls', cacheAll: true);

  @override
  String get defaultSort => 'name';

  @override
  Hall fromJson(Map<String, dynamic> json) => Hall.fromJson(json);

  @override
  Map<String, dynamic> toBody(Hall item) => item.toBody();

  @override
  String idOf(Hall item) => item.id;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()
      ..addIf(query.search, (q) => 'name ~ $q')
      ..addIf(query.filter('format'), (q) => 'format = $q');
    return filter.build();
  }
}

class PbMovieRepository extends PbRepository<Movie> {
  PbMovieRepository({required super.dio, super.now})
    : super(collection: 'movies', expand: 'genres,directors,actors', cacheAll: true);

  @override
  String get defaultSort => 'title';

  @override
  Movie fromJson(Map<String, dynamic> json) => Movie.fromJson(json);

  @override
  Map<String, dynamic> toBody(Movie item) => item.toBody();

  @override
  String idOf(Movie item) => item.id;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()
      ..addIf(query.search, (q) => 'title ~ $q || country ~ $q')
      ..addIf(query.filter('genre'), (q) => 'genres ?= $q')
      ..addIf(query.filter('age'), (q) => 'ageRating = $q');
    final from = jsonInt(query.filter('yearFrom'), -1);
    final to = jsonInt(query.filter('yearTo'), -1);
    if (from >= 0) filter.add('year >= $from');
    if (to >= 0) filter.add('year <= $to');
    return filter.build();
  }
}
