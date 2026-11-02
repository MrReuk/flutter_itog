import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/pricing.dart';
import '../models/screening.dart';
import '../models/ticket.dart';
import '../repositories/entity_repository.dart';
import '../repositories/sales_repositories.dart';
import '../repositories/screening_repository.dart';
import 'load_status.dart';
import 'paged_list_notifier.dart';

typedef Seat = ({int row, int seat});

class BookingNotifier extends ChangeNotifier {
  BookingNotifier({
    required this.screeningId,
    required EntityRepository<Screening> screenings,
    required ScreeningRepository seats,
    required OrderRepository orders,
    this.customerId,
  }) : _screenings = screenings,
       _seats = seats,
       _orders = orders;

  final String screeningId;

  final String? customerId;

  final EntityRepository<Screening> _screenings;
  final ScreeningRepository _seats;
  final OrderRepository _orders;

  LoadStatus _status = LoadStatus.idle;
  String? _error;
  Screening? _screening;
  Set<Seat> _taken = {};
  final Map<Seat, TicketCategory> _chosen = {};
  bool _submitting = false;
  String? _submitError;
  CheckoutResult? _result;
  bool _disposed = false;

  LoadStatus get status => _status;
  String? get error => _error;
  Screening? get screening => _screening;
  bool get submitting => _submitting;
  String? get submitError => _submitError;

  CheckoutResult? get result => _result;

  Set<Seat> get taken => Set.unmodifiable(_taken);
  Map<Seat, TicketCategory> get chosen => Map.unmodifiable(_chosen);

  bool isTaken(int row, int seat) => _taken.contains((row: row, seat: seat));
  bool isChosen(int row, int seat) => _chosen.containsKey((row: row, seat: seat));

  bool isStarted(DateTime now) {
    final s = _screening;
    return s != null && !s.startsAt.isAfter(now);
  }

  int priceFor(TicketCategory category) {
    final s = _screening;
    final hall = s?.hall;
    if (s == null || hall == null) return 0;
    return ticketPrice(
      basePrice: s.basePrice,
      hallFactor: hall.priceFactor,
      category: category,
      startsAt: s.startsAt,
    );
  }

  int get total => _chosen.values.fold(0, (sum, c) => sum + priceFor(c));

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final screening = await _screenings.findById(screeningId);
      if (screening == null) {
        _error = 'Сеанс не найден.';
        _status = LoadStatus.error;
        notifyListeners();
        return;
      }
      _screening = screening;
      await _loadTaken();
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить сеанс: ${describeError(e)}';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> _loadTaken() async {
    final list = await _seats.takenSeats(screeningId);
    _taken = {for (final s in list) (row: s.row, seat: s.seat)};
    _chosen.removeWhere((seat, _) => _taken.contains(seat));
  }

  void toggle(int row, int seat) {
    final key = (row: row, seat: seat);
    if (_taken.contains(key)) return;
    if (_chosen.containsKey(key)) {
      _chosen.remove(key);
    } else {
      _chosen[key] = TicketCategory.full;
    }
    _submitError = null;
    notifyListeners();
  }

  void setCategory(int row, int seat, TicketCategory category) {
    final key = (row: row, seat: seat);
    if (!_chosen.containsKey(key)) return;
    _chosen[key] = category;
    notifyListeners();
  }

  void clear() {
    _chosen.clear();
    _submitError = null;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (_submitting || _chosen.isEmpty) return false;
    _submitting = true;
    _submitError = null;
    notifyListeners();

    final seats = [
      for (final entry in _chosen.entries)
        (row: entry.key.row, seat: entry.key.seat, category: entry.value),
    ]..sort((a, b) => a.row != b.row ? a.row.compareTo(b.row) : a.seat.compareTo(b.seat));

    try {
      _result = await _orders.checkout(
        screeningId: screeningId,
        customerId: customerId,
        seats: seats,
      );
      _chosen.clear();
      _submitting = false;
      notifyListeners();
      return true;
    } on ConflictException catch (e) {
      _submitError =
          'Не удалось купить билеты: ${e.errors['seat'] ?? e.message} '
          'Схема зала обновлена, выберите другие места.';
      await _refreshAfterConflict();
    } catch (e) {
      _submitError = 'Не удалось купить билеты: ${describeError(e)}';
    }
    _submitting = false;
    notifyListeners();
    return false;
  }

  Future<void> _refreshAfterConflict() async {
    try {
      await _loadTaken();
    } catch (_) {}
  }

  void dismissResult() {
    _result = null;
    notifyListeners();
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
