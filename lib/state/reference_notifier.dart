import 'package:flutter/foundation.dart';

import '../models/genre.dart';
import '../models/hall.dart';
import '../models/movie.dart';
import '../models/named_option.dart';
import '../models/person.dart';
import '../repositories/catalog_repositories.dart';
import 'paged_list_notifier.dart';

class ReferenceNotifier extends ChangeNotifier {
  ReferenceNotifier({
    required GenreRepository genres,
    required PersonRepository people,
    required HallRepository halls,
    required MovieRepository movies,
  }) : _genres = genres,
       _people = people,
       _halls = halls,
       _movies = movies;

  final GenreRepository _genres;
  final PersonRepository _people;
  final HallRepository _halls;
  final MovieRepository _movies;

  List<Genre> _genreList = const [];
  List<Person> _peopleList = const [];
  List<Hall> _hallList = const [];
  List<Movie> _movieList = const [];
  bool _ready = false;
  bool _failed = false;
  String? _error;
  bool _disposed = false;

  bool get ready => _ready;
  bool get failed => _failed;
  String? get error => _error;

  List<Hall> get halls => _hallList;
  List<Movie> get movies => _movieList;

  Hall? hallById(String id) {
    for (final hall in _hallList) {
      if (hall.id == id) return hall;
    }
    return null;
  }

  Movie? movieById(String id) {
    for (final movie in _movieList) {
      if (movie.id == id) return movie;
    }
    return null;
  }

  String genreTitle(String id) {
    for (final genre in _genreList) {
      if (genre.id == id) return genre.title;
    }
    return '—';
  }

  List<NamedOption> genreOptions() =>
      _sorted([for (final g in _genreList) (id: g.id, name: g.title)]);

  List<NamedOption> personOptions() =>
      _sorted([for (final p in _peopleList) (id: p.id, name: p.fullName)]);

  List<NamedOption> hallOptions() =>
      _sorted([for (final h in _hallList) (id: h.id, name: '${h.name} (${h.format})')]);

  List<NamedOption> movieOptions() =>
      _sorted([for (final m in _movieList) (id: m.id, name: '${m.title} (${m.year})')]);

  List<String> countries() {
    final set = <String>{
      for (final p in _peopleList)
        if (p.country.isNotEmpty) p.country,
    };
    return set.toList()..sort();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait<Object?>([
        _genres.findAll(),
        _people.findAll(),
        _halls.findAll(),
        _movies.findAll(),
      ]);
      _genreList = results[0] as List<Genre>;
      _peopleList = results[1] as List<Person>;
      _hallList = results[2] as List<Hall>;
      _movieList = results[3] as List<Movie>;
      _failed = false;
      _error = null;
      _ready = true;
    } catch (e) {
      _failed = true;
      _error = describeError(e);
    }
    notifyListeners();
  }

  List<NamedOption> _sorted(List<NamedOption> list) {
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
