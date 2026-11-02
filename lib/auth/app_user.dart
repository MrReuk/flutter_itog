import '../models/json_helpers.dart';
import 'role.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final Role role;

  const AppUser({required this.id, required this.email, required this.name, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final email = jsonString(json['email']);
    final name = jsonString(json['name']).trim();
    return AppUser(
      id: jsonString(json['id']),
      email: email,
      name: name.isEmpty ? email : name,
      role: Role.tryParse(json['role']) ?? Role.viewer,
    );
  }

  Map<String, Object?> toJson() => {'id': id, 'email': email, 'name': name, 'role': role.code};
}
