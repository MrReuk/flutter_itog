import 'json_helpers.dart';

const List<String> kHallFormats = ['2D', '3D', 'IMAX', 'VIP'];

class Hall {
  final String id;
  final String name;
  final String format;
  final int rows;
  final int seatsPerRow;

  final double priceFactor;

  const Hall({
    required this.id,
    required this.name,
    required this.format,
    required this.rows,
    required this.seatsPerRow,
    required this.priceFactor,
  });

  factory Hall.fromJson(Map<String, dynamic> json) {
    return Hall(
      id: jsonString(json['id']),
      name: jsonString(json['name']),
      format: jsonString(json['format'], '2D'),
      rows: jsonInt(json['rows']),
      seatsPerRow: jsonInt(json['seatsPerRow']),
      priceFactor: jsonDouble(json['priceFactor'], 1),
    );
  }

  int get seats => rows * seatsPerRow;

  Map<String, dynamic> toBody() => {
    'name': name.trim(),
    'format': format,
    'rows': rows,
    'seatsPerRow': seatsPerRow,
    'priceFactor': priceFactor,
  };
}
