import 'json_helpers.dart';

class Person {
  final String id;
  final String fullName;
  final String country;
  final DateTime? birthDate;

  const Person({required this.id, required this.fullName, this.country = '', this.birthDate});

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: jsonString(json['id']),
      fullName: jsonString(json['fullName']),
      country: jsonString(json['country']),
      birthDate: jsonDate(json['birthDate']),
    );
  }

  Map<String, dynamic> toBody() => {
    'fullName': fullName.trim(),
    'country': country.trim(),
    'birthDate': birthDate == null ? '' : toPbDate(birthDate!),
  };
}
