import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/format.dart';
import '../models/screening.dart';
import '../models/ticket.dart';
import '../repositories/sales_repositories.dart';
import '../repositories/screening_repository.dart';
import '../state/booking_notifier.dart';
import '../state/load_status.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/seat_map.dart';
import '../widgets/state_views.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.screeningId});

  final String screeningId;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthNotifier>();
    final screenings = context.read<ScreeningRepository>();
    final orders = context.read<OrderRepository>();
    return ChangeNotifierProvider<BookingNotifier>(
      key: ValueKey('booking-$screeningId'),
      create: (_) => BookingNotifier(
        screeningId: screeningId,
        screenings: screenings,
        seats: screenings,
        orders: orders,
        customerId: auth.can(Permission.buyTickets) ? auth.user?.id : null,
      )..load(),
      child: const _BookingView(),
    );
  }
}

class _BookingView extends StatelessWidget {
  const _BookingView();

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingNotifier>();
    final auth = context.watch<AuthNotifier>();
    final cashier = auth.can(Permission.useBoxOffice);

    Widget body;
    if (booking.result != null) {
      body = _ResultView(booking: booking, cashier: cashier);
    } else {
      body = switch (booking.status) {
        LoadStatus.idle || LoadStatus.loading => const LoadingView(),
        LoadStatus.error => ErrorView(
          message: booking.error ?? 'Неизвестная ошибка',
          onRetry: booking.load,
        ),
        LoadStatus.success => _SeatsView(booking: booking, auth: auth),
      };
    }

    return AppScaffold(
      title: 'Выбор мест',
      showBack: true,
      backPath: cashier ? '/box-office' : '/screenings',
      body: body,
    );
  }
}

class _SeatsView extends StatelessWidget {
  const _SeatsView({required this.booking, required this.auth});

  final BookingNotifier booking;
  final AuthNotifier auth;

  @override
  Widget build(BuildContext context) {
    final screening = booking.screening!;
    final hall = screening.hall;
    final canSell = auth.can(Permission.buyTickets) || auth.can(Permission.useBoxOffice);
    final closed = auth.can(Permission.buyTickets) && booking.isStarted(DateTime.now());

    if (hall == null) {
      return const EmptyView(message: 'Для сеанса не указан зал.');
    }

    final map = SeatMap(
      rows: hall.rows,
      seatsPerRow: hall.seatsPerRow,
      stateOf: (row, seat) {
        if (booking.isTaken(row, seat)) return SeatState.taken;
        if (booking.isChosen(row, seat)) return SeatState.chosen;
        return SeatState.free;
      },
      onTap: (row, seat) {
        if (canSell && !closed) booking.toggle(row, seat);
      },
    );

    final notice = !canSell
        ? 'Покупка билетов недоступна для вашей роли: схема зала открыта для просмотра.'
        : closed
        ? 'Сеанс уже начался, продажа билетов закрыта.'
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final panel = _OrderPanel(booking: booking, canSell: canSell && !closed, auth: auth);
        final header = _ScreeningHeader(screening: screening);
        final mapCard = Card(
          child: Padding(padding: const EdgeInsets.all(16), child: map),
        );

        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      header,
                      if (notice != null) _Notice(text: notice),
                      mapCard,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 340, child: SingleChildScrollView(child: panel)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            header,
            if (notice != null) _Notice(text: notice),
            mapCard,
            const SizedBox(height: 12),
            panel,
          ],
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreeningHeader extends StatelessWidget {
  const _ScreeningHeader({required this.screening});

  final Screening screening;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hall = screening.hall;
    final end = screening.endsAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(screening.movieTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${formatCinemaShort(screening.startsAt)}'
              '${end == null ? '' : ' – ${formatCinemaClock(end)}'}',
            ),
            Text(
              '${hall == null ? 'Зал' : '${hall.name}, ${hall.format}'} · ${screening.language}',
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({required this.booking, required this.canSell, required this.auth});

  final BookingNotifier booking;
  final bool canSell;
  final AuthNotifier auth;

  Future<void> _submit(BuildContext context) async {
    final count = booking.chosen.length;
    final confirmed = await confirmAction(
      context,
      title: 'Оформить заказ?',
      message: 'Билетов: $count, к оплате ${formatRub(booking.total)}.',
      confirmLabel: 'Оформить',
    );
    if (!confirmed) return;
    await booking.submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cashier = auth.can(Permission.useBoxOffice);
    final seats = booking.chosen.entries.toList()
      ..sort((a, b) {
        final byRow = a.key.row.compareTo(b.key.row);
        return byRow != 0 ? byRow : a.key.seat.compareTo(b.key.seat);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ваш заказ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (seats.isEmpty)
              const Text('Выберите места на схеме зала.')
            else
              for (final entry in seats)
                _SeatLine(
                  key: ValueKey('line-${entry.key.row}-${entry.key.seat}'),
                  row: entry.key.row,
                  seat: entry.key.seat,
                  category: entry.value,
                  price: booking.priceFor(entry.value),
                  onCategory: (c) => booking.setCategory(entry.key.row, entry.key.seat, c),
                  onRemove: () => booking.toggle(entry.key.row, entry.key.seat),
                ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Итого', style: theme.textTheme.titleMedium),
                Text(
                  formatRub(booking.total),
                  key: const ValueKey('order-total'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (booking.submitError != null) ...[
              const SizedBox(height: 8),
              Text(
                booking.submitError!,
                key: const ValueKey('submit-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (canSell)
              FilledButton.icon(
                key: const ValueKey('buy-button'),
                onPressed: seats.isEmpty || booking.submitting ? null : () => _submit(context),
                icon: booking.submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_cart_checkout),
                label: Text(cashier ? 'Оформить продажу' : 'Купить билеты'),
              ),
            if (seats.isNotEmpty)
              TextButton(onPressed: booking.clear, child: const Text('Очистить выбор')),
          ],
        ),
      ),
    );
  }
}

class _SeatLine extends StatelessWidget {
  const _SeatLine({
    super.key,
    required this.row,
    required this.seat,
    required this.category,
    required this.price,
    required this.onCategory,
    required this.onRemove,
  });

  final int row;
  final int seat;
  final TicketCategory category;
  final int price;
  final ValueChanged<TicketCategory> onCategory;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Ряд $row, место $seat')),
          Expanded(
            flex: 4,
            child: DropdownButton<TicketCategory>(
              value: category,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in TicketCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (value) {
                if (value != null) onCategory(value);
              },
            ),
          ),
          SizedBox(width: 72, child: Text(formatRub(price), textAlign: TextAlign.end)),
          IconButton(
            tooltip: 'Убрать место',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.booking, required this.cashier});

  final BookingNotifier booking;
  final bool cashier;

  @override
  Widget build(BuildContext context) {
    final result = booking.result!;
    final screening = booking.screening;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Заказ оформлен',
                            key: const ValueKey('order-done'),
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (screening != null)
                      Text('${screening.movieTitle}, ${formatCinemaShort(screening.startsAt)}'),
                    if (screening != null) Text(screening.hallName),
                    const SizedBox(height: 12),
                    for (final ticket in result.tickets)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.confirmation_number_outlined),
                        title: Text('Ряд ${ticket.row}, место ${ticket.seat}'),
                        subtitle: Text(ticket.category.label),
                        trailing: Text(formatRub(ticket.price)),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Итого', style: theme.textTheme.titleMedium),
                        Text(formatRub(result.order.total), style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () =>
                              context.go(cashier ? '/orders/${result.order.id}' : '/my/tickets'),
                          child: Text(cashier ? 'Открыть заказ' : 'Мои билеты'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            booking.dismissResult();
                            booking.load();
                          },
                          child: Text(cashier ? 'Новая продажа' : 'Купить ещё'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
