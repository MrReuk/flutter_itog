import 'json_helpers.dart';
import 'screening.dart';

enum TicketCategory {
  full('full', 'Полный', 1),
  child('child', 'Детский', 0.5),
  student('student', 'Студенческий', 0.7);

  const TicketCategory(this.code, this.label, this.factor);

  final String code;
  final String label;

  final double factor;

  static TicketCategory parse(Object? value) {
    for (final c in TicketCategory.values) {
      if (c.code == value) return c;
    }
    return TicketCategory.full;
  }
}

enum TicketStatus {
  sold('sold', 'Действует'),
  returned('returned', 'Возвращён'),
  used('used', 'Использован');

  const TicketStatus(this.code, this.label);

  final String code;
  final String label;

  static TicketStatus parse(Object? value) {
    for (final s in TicketStatus.values) {
      if (s.code == value) return s;
    }
    return TicketStatus.sold;
  }
}

class Ticket {
  final String id;
  final String orderId;
  final String screeningId;
  final int row;
  final int seat;
  final TicketCategory category;
  final int price;
  final TicketStatus status;
  final Screening? screening;

  const Ticket({
    required this.id,
    required this.orderId,
    required this.screeningId,
    required this.row,
    required this.seat,
    required this.category,
    required this.price,
    required this.status,
    this.screening,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final screening = expandedOne(json, 'screening');
    return Ticket(
      id: jsonString(json['id']),
      orderId: jsonRefId(json['order']),
      screeningId: jsonRefId(json['screening']),
      row: jsonInt(json['row']),
      seat: jsonInt(json['seat']),
      category: TicketCategory.parse(json['category']),
      price: jsonInt(json['price']),
      status: TicketStatus.parse(json['status']),
      screening: screening.isEmpty ? null : Screening.fromJson(screening),
    );
  }

  String get placeText => 'ряд $row, место $seat';
}
