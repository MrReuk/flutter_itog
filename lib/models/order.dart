import 'json_helpers.dart';
import 'screening.dart';

enum OrderStatus {
  paid('paid', 'Оплачен'),
  refunded('refunded', 'Возвращён');

  const OrderStatus(this.code, this.label);

  final String code;
  final String label;

  static OrderStatus parse(Object? value) {
    return value == 'refunded' ? OrderStatus.refunded : OrderStatus.paid;
  }
}

class Order {
  final String id;
  final String screeningId;
  final String customerId;
  final String cashierId;
  final OrderStatus status;
  final int total;
  final DateTime? created;
  final Screening? screening;

  final String customerName;

  const Order({
    required this.id,
    required this.screeningId,
    this.customerId = '',
    this.cashierId = '',
    required this.status,
    required this.total,
    this.created,
    this.screening,
    this.customerName = '',
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final screening = expandedOne(json, 'screening');
    final customer = expandedOne(json, 'customer');
    return Order(
      id: jsonString(json['id']),
      screeningId: jsonRefId(json['screening']),
      customerId: jsonRefId(json['customer']),
      cashierId: jsonRefId(json['cashier']),
      status: OrderStatus.parse(json['status']),
      total: jsonInt(json['total']),
      created: jsonDate(json['created']),
      screening: screening.isEmpty ? null : Screening.fromJson(screening),
      customerName: jsonString(customer['name']),
    );
  }

  bool get isBoxOffice => cashierId.isNotEmpty;
}
