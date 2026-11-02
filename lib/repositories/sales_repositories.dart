import '../core/api_exceptions.dart';
import '../models/json_helpers.dart';
import '../models/list_query.dart';
import '../models/order.dart';
import '../models/ticket.dart';
import 'entity_repository.dart';
import 'pb_repository.dart';
import 'screening_repository.dart';

typedef SeatChoice = ({int row, int seat, TicketCategory category});

class CheckoutResult {
  const CheckoutResult({required this.order, required this.tickets});

  final Order order;
  final List<Ticket> tickets;

  int get total => tickets.fold(0, (sum, t) => sum + t.price);
}

abstract interface class OrderRepository implements EntityRepository<Order> {
  Future<List<Ticket>> ticketsOf(String orderId);

  Future<CheckoutResult> checkout({
    required String screeningId,
    String? customerId,
    required List<SeatChoice> seats,
  });

  Future<void> refund(String orderId);
}

abstract interface class TicketRepository implements EntityRepository<Ticket> {
  Future<Ticket> setStatus(String id, TicketStatus status);
}

const String _ticketExpand = 'screening.movie,screening.hall';

class PbTicketRepository extends PbRepository<Ticket> implements TicketRepository {
  PbTicketRepository({required super.dio, super.now})
    : super(collection: 'tickets', expand: _ticketExpand);

  @override
  Ticket fromJson(Map<String, dynamic> json) => Ticket.fromJson(json);

  @override
  Map<String, dynamic> toBody(Ticket item) => {
    'order': item.orderId,
    'screening': item.screeningId,
    'row': item.row,
    'seat': item.seat,
    'category': item.category.code,
    'status': item.status.code,
  };

  @override
  String idOf(Ticket item) => item.id;

  @override
  String sortFieldOf(String field) => field == 'screening' ? 'screening.startsAt' : field;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()
      ..addIf(query.search, (q) => 'id = $q || screening.movie.title ~ $q')
      ..addIf(query.filter('status'), (q) => 'status = $q')
      ..addIf(query.filter('category'), (q) => 'category = $q')
      ..addIf(query.filter('screening'), (q) => 'screening = $q');
    final period = periodFilter('screening.startsAt', query.filter('period'), clock());
    if (period.isNotEmpty) filter.add(period);
    return filter.build();
  }

  @override
  Future<Ticket> setStatus(String id, TicketStatus status) {
    return guard(() async {
      final response = await dio.patch<dynamic>(
        '$path/$id',
        data: {'status': status.code},
        queryParameters: {'expand': _ticketExpand},
      );
      return Ticket.fromJson(jsonMap(response.data));
    });
  }
}

class PbOrderRepository extends PbRepository<Order> implements OrderRepository {
  PbOrderRepository({required super.dio, super.now})
    : super(collection: 'orders', expand: 'screening.movie,screening.hall,customer');

  @override
  Order fromJson(Map<String, dynamic> json) => Order.fromJson(json);

  @override
  Map<String, dynamic> toBody(Order item) => {
    'screening': item.screeningId,
    if (item.customerId.isNotEmpty) 'customer': item.customerId,
    'status': item.status.code,
  };

  @override
  String idOf(Order item) => item.id;

  @override
  String filterOf(ListQuery query) {
    final filter = FilterBuilder()
      ..addIf(query.search, (q) => 'customer.name ~ $q || customer.email ~ $q || id = $q')
      ..addIf(query.filter('status'), (q) => 'status = $q')
      ..addIf(query.filter('screening'), (q) => 'screening = $q');
    switch (query.filter('channel')) {
      case 'box':
        filter.add("cashier != ''");
      case 'online':
        filter.add("cashier = ''");
    }
    final date = query.filter('date');
    if (date.isNotEmpty) {
      final range = dayRange(date);
      if (range.from.isNotEmpty) {
        filter.add('created >= ${pbQuote(range.from)} && created < ${pbQuote(range.to)}');
      }
    }
    return filter.build();
  }

  @override
  Future<List<Ticket>> ticketsOf(String orderId) {
    return guard(() async {
      final response = await dio.get<dynamic>(
        '/collections/tickets/records',
        queryParameters: {
          'filter': 'order = ${pbQuote(orderId)}',
          'perPage': 200,
          'sort': 'row,seat',
          'expand': _ticketExpand,
        },
      );
      final items = jsonMap(response.data)['items'];
      if (items is! List) throw const FormatException('Нет списка билетов');
      return [for (final e in items) Ticket.fromJson(jsonMap(e))];
    });
  }

  @override
  Future<CheckoutResult> checkout({
    required String screeningId,
    String? customerId,
    required List<SeatChoice> seats,
  }) {
    return guard(() async {
      if (seats.isEmpty) {
        throw const ValidationException('Выберите хотя бы одно место.', {});
      }
      final orderResponse = await dio.post<dynamic>(
        path,
        data: {
          'screening': screeningId,
          if (customerId != null && customerId.isNotEmpty) 'customer': customerId,
          'status': 'paid',
        },
      );
      final orderId = jsonString(jsonMap(orderResponse.data)['id']);

      final created = <Ticket>[];
      try {
        for (final seat in seats) {
          final response = await dio.post<dynamic>(
            '/collections/tickets/records',
            data: {
              'order': orderId,
              'screening': screeningId,
              'row': seat.row,
              'seat': seat.seat,
              'category': seat.category.code,
              'status': 'sold',
            },
          );
          created.add(Ticket.fromJson(jsonMap(response.data)));
        }
      } catch (_) {
        await _rollback(orderId, created);
        rethrow;
      }
      final order = await findById(orderId);
      if (order == null) {
        throw const ServerException('Заказ не найден после оформления.');
      }
      return CheckoutResult(order: order, tickets: created);
    });
  }

  Future<void> _rollback(String orderId, List<Ticket> created) async {
    try {
      for (final ticket in created) {
        await dio.patch<dynamic>(
          '/collections/tickets/records/${ticket.id}',
          data: {'status': 'returned'},
        );
      }
      await dio.patch<dynamic>('$path/$orderId', data: {'status': 'refunded'});
    } catch (_) {}
  }

  @override
  Future<void> refund(String orderId) {
    return guard(() async {
      final tickets = await ticketsOf(orderId);
      if (tickets.any((t) => t.status == TicketStatus.used)) {
        throw const ConflictException('В заказе есть использованные билеты: вернуть его нельзя.');
      }
      for (final ticket in tickets.where((t) => t.status == TicketStatus.sold)) {
        await dio.patch<dynamic>(
          '/collections/tickets/records/${ticket.id}',
          data: {'status': 'returned'},
        );
      }
      await dio.patch<dynamic>('$path/$orderId', data: {'status': 'refunded'});
    });
  }
}
