import 'json_helpers.dart';

class Genre {
  final String id;
  final String title;

  const Genre({required this.id, required this.title});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(id: jsonString(json['id']), title: jsonString(json['title']));
  }

  Map<String, dynamic> toBody() => {'title': title.trim()};
}
