import 'json_helpers.dart';

class ViewerProfile {
  final String id;
  final String userId;
  final String phone;
  final DateTime? birthDate;
  final bool student;
  final String favoriteGenreId;

  const ViewerProfile({
    required this.id,
    required this.userId,
    this.phone = '',
    this.birthDate,
    this.student = false,
    this.favoriteGenreId = '',
  });

  factory ViewerProfile.fromJson(Map<String, dynamic> json) {
    return ViewerProfile(
      id: jsonString(json['id']),
      userId: jsonRefId(json['user']),
      phone: jsonString(json['phone']),
      birthDate: jsonDate(json['birthDate']),
      student: jsonBool(json['student']),
      favoriteGenreId: jsonRefId(json['favoriteGenre']),
    );
  }

  Map<String, dynamic> toBody() => {
    'phone': phone.trim(),
    'birthDate': birthDate == null ? '' : toPbDate(birthDate!),
    'student': student,
    'favoriteGenre': favoriteGenreId,
  };
}
