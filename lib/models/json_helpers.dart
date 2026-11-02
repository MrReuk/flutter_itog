int jsonInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

double jsonDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

bool jsonBool(Object? value) => value == true;

String jsonString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return '$value';
}

String jsonRefId(Object? value) {
  if (value is Map) return jsonString(value['id']);
  return jsonString(value);
}

List<String> jsonRefIds(Object? value) {
  if (value is! List) {
    return value is String && value.isNotEmpty ? [value] : <String>[];
  }
  return <String>[
    for (final element in value)
      if (jsonRefId(element).isNotEmpty) jsonRefId(element),
  ];
}

DateTime? jsonDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value.replaceFirst(' ', 'T'));
}

String toPbDate(DateTime value) {
  return value.toUtc().toIso8601String().replaceFirst('T', ' ');
}

Map<String, dynamic> jsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> expandedOne(Map<String, dynamic> json, String field) {
  final expand = json['expand'];
  if (expand is Map && expand[field] is Map) return jsonMap(expand[field]);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> expandedMany(Map<String, dynamic> json, String field) {
  final expand = json['expand'];
  if (expand is Map && expand[field] is List) {
    return [for (final e in expand[field] as List) jsonMap(e)];
  }
  return const [];
}
