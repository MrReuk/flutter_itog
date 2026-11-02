import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/format.dart';
import '../models/list_query.dart';
import '../models/order.dart';
import '../models/ticket.dart';
import '../repositories/sales_repositories.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/choice_dropdown.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/date_filter_field.dart';
import '../widgets/detail_layout.dart';
import '../widgets/entity_table.dart';
import '../widgets/state_views.dart';
import 'entity_list_screen.dart';
import 'screening_screens.dart';

String _orderTitle(Order o) {
  final s = o.screening;
  final what = s == null ? 'Заказ' : '${s.movieTitle}, ${formatCinemaShort(s.startsAt)}';
  return what;
}

String _buyerOf(Order o) {
  if (o.customerName.isNotEmpty) return o.customerName;
  return o.isBoxOffice ? 'Покупатель на кассе' : '—';
}

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key, required this.query});

  final ListQuery query;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthNotifier>().can(Permission.manageCatalog);
    return EntityListScreen<Order>(
      title: 'Заказы',
      path: '/orders',
      query: query,
      searchLabel: 'Поиск по покупателю или номеру заказа',
      emptyMessage: 'Заказы не найдены. Измените поиск или фильтры.',
      canManage: admin,
      openPath: (o) => '/orders/${o.id}',
      idOf: (o) => o.id,
      titleOf: _orderTitle,
      deleteName: (o) => 'Заказ ${o.id}',
      subtitleOf: (o) =>
          '${_buyerOf(o)} · ${o.isBoxOffice ? 'касса' : 'сайт'}\n'
          '${formatRub(o.total)} · ${o.status.label}',
      filters: (context, q, apply) => [
        ChoiceDropdown(
          label: 'Статус',
          value: q.filter('status'),
          width: 180,
          choices: [for (final s in OrderStatus.values) (value: s.code, label: s.label)],
          onChanged: (value) => apply(q.withFilter('status', value)),
        ),
        ChoiceDropdown(
          label: 'Канал продажи',
          value: q.filter('channel'),
          width: 200,
          choices: const [(value: 'online', label: 'Сайт'), (value: 'box', label: 'Касса')],
          onChanged: (value) => apply(q.withFilter('channel', value)),
        ),
        DateFilterField(
          label: 'Дата заказа',
          value: q.filter('date'),
          onChanged: (value) => apply(q.withFilter('date', value)),
        ),
      ],
      columns: [
        TableColumnSpec<Order>(label: 'Номер', build: (o) => Text(o.id)),
        TableColumnSpec<Order>(
          label: 'Сеанс',
          build: (o) => CellText(_orderTitle(o), maxWidth: 300),
        ),
        TableColumnSpec<Order>(
          label: 'Покупатель',
          hideBelow: 950,
          build: (o) => CellText(_buyerOf(o), maxWidth: 200),
        ),
        TableColumnSpec<Order>(
          label: 'Канал',
          hideBelow: 1050,
          build: (o) => Text(o.isBoxOffice ? 'Касса' : 'Сайт'),
        ),
        TableColumnSpec<Order>(
          label: 'Сумма',
          sortField: 'total',
          numeric: true,
          build: (o) => Text(formatRub(o.total)),
        ),
        TableColumnSpec<Order>(label: 'Статус', build: (o) => Text(o.status.label)),
        TableColumnSpec<Order>(
          label: 'Создан',
          sortField: 'created',
          hideBelow: 1100,
          build: (o) => Text(o.created == null ? '—' : formatCinemaShort(o.created!)),
        ),
      ],
    );
  }
}

typedef _OrderPage = ({Order? order, List<Ticket> tickets});

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<_OrderPage> _loading;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<_OrderPage> _load() async {
    final orders = context.read<OrderRepository>();
    final order = await orders.findById(widget.orderId);
    if (order == null) return (order: null, tickets: <Ticket>[]);
    return (order: order, tickets: await orders.ticketsOf(order.id));
  }

  void _reload() => setState(() {
    _loading = _load();
  });

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) {
        await showNotice(context, title: 'Действие невозможно', message: describeError(e));
      }
    }
    if (mounted) _reload();
  }

  Future<void> _refund(Order order) async {
    final ok = await confirmAction(
      context,
      title: 'Вернуть заказ?',
      message: 'Все действующие билеты заказа будут возвращены, места освободятся.',
      confirmLabel: 'Вернуть',
    );
    if (!ok || !mounted) return;
    await _run(() => context.read<OrderRepository>().refund(order.id), 'Заказ возвращён');
  }

  Future<void> _setStatus(Ticket ticket, TicketStatus status) async {
    await _run(
      () => context.read<TicketRepository>().setStatus(ticket.id, status),
      status == TicketStatus.used ? 'Билет отмечен как использованный' : 'Билет возвращён',
    );
  }

  Future<void> _delete(Order order) async {
    final ok = await confirmAction(
      context,
      title: 'Удалить заказ?',
      message: 'Заказ и его билеты будут удалены без возможности восстановления.',
    );
    if (!ok || !mounted) return;
    final router = GoRouter.of(context);
    try {
      await context.read<OrderRepository>().delete(order.id);
      router.go('/orders');
    } catch (e) {
      if (mounted) {
        await showNotice(context, title: 'Действие невозможно', message: describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Заказ',
      showBack: true,
      backPath: '/orders',
      body: FutureBuilder<_OrderPage>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Не удалось загрузить заказ: ${describeError(snapshot.error!)}',
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          final order = data.order;
          if (order == null) {
            return EmptyView(
              message: 'Заказ не найден',
              actionLabel: 'К заказам',
              onAction: () => context.go('/orders'),
            );
          }
          return _content(context, order, data.tickets);
        },
      ),
    );
  }

  Widget _content(BuildContext context, Order order, List<Ticket> tickets) {
    final auth = context.watch<AuthNotifier>();
    final canCheck = auth.can(Permission.checkTickets);
    final hasSold = tickets.any((t) => t.status == TicketStatus.sold);
    final theme = Theme.of(context);
    return DetailLayout(
      title: _orderTitle(order),
      actions: [
        if (canCheck && order.status == OrderStatus.paid && hasSold)
          FilledButton.tonalIcon(
            onPressed: () => _refund(order),
            icon: const Icon(Icons.undo),
            label: const Text('Вернуть заказ'),
          ),
        if (auth.can(Permission.manageCatalog))
          OutlinedButton.icon(
            onPressed: () => _delete(order),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить'),
          ),
      ],
      children: [
        DetailField(label: 'Номер заказа', child: Text(order.id)),
        DetailField(label: 'Покупатель', child: Text(_buyerOf(order))),
        DetailField(label: 'Канал продажи', child: Text(order.isBoxOffice ? 'Касса' : 'Сайт')),
        DetailField(label: 'Статус', child: Text(order.status.label)),
        DetailField(label: 'Сумма', child: Text(formatRub(order.total))),
        if (order.created != null)
          DetailField(label: 'Оформлен', child: Text(formatCinemaDateTime(order.created!))),
        const Divider(height: 32),
        Text('Билеты', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final ticket in tickets)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text('Ряд ${ticket.row}, место ${ticket.seat}'),
              subtitle: Text(
                '${ticket.category.label} · ${formatRub(ticket.price)} · ${ticket.status.label}',
              ),
              trailing: canCheck && ticket.status == TicketStatus.sold
                  ? Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Отметить как использованный',
                          icon: const Icon(Icons.how_to_reg),
                          onPressed: () => _setStatus(ticket, TicketStatus.used),
                        ),
                        IconButton(
                          tooltip: 'Вернуть билет',
                          icon: const Icon(Icons.undo),
                          onPressed: () => _setStatus(ticket, TicketStatus.returned),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

String _ticketTitle(Ticket t) {
  final s = t.screening;
  final what = s == null ? 'Билет' : '${s.movieTitle}, ${formatCinemaShort(s.startsAt)}';
  return what;
}

class TicketListScreen extends StatelessWidget {
  const TicketListScreen({super.key, required this.query, this.mine = false});

  final ListQuery query;
  final bool mine;

  Future<void> _change(BuildContext context, Ticket ticket, TicketStatus status) async {
    final notifier = context.read<PagedListNotifier<Ticket>>();
    final tickets = context.read<TicketRepository>();
    final messenger = ScaffoldMessenger.of(context);
    if (status == TicketStatus.returned) {
      final ok = await confirmAction(
        context,
        title: 'Вернуть билет?',
        message: 'Место ${ticket.placeText} освободится для других зрителей.',
        confirmLabel: 'Вернуть',
      );
      if (!ok) return;
    }
    try {
      await tickets.setStatus(ticket.id, status);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == TicketStatus.used ? 'Билет отмечен как использованный' : 'Билет возвращён',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось выполнить: ${describeError(e)}')));
    }
    await notifier.load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final staff = auth.can(Permission.checkTickets);
    final admin = auth.can(Permission.manageCatalog);
    final path = mine ? '/my/tickets' : '/tickets';
    return EntityListScreen<Ticket>(
      title: mine ? 'Мои билеты' : 'Билеты',
      path: path,
      query: query,
      searchLabel: 'Поиск по фильму или номеру билета',
      emptyMessage: mine
          ? 'У вас пока нет билетов. Выберите сеанс в афише.'
          : 'Билеты не найдены. Измените поиск или фильтры.',
      canManage: admin && !mine,
      idOf: (t) => t.id,
      titleOf: _ticketTitle,
      deleteName: (t) => 'Билет ${t.id}',
      subtitleOf: (t) =>
          '${t.placeText} · ${t.category.label}\n${formatRub(t.price)} · ${t.status.label}',
      extraActions: (context, t) {
        final started = t.screening != null && !t.screening!.startsAt.isAfter(DateTime.now());
        final canReturn = t.status == TicketStatus.sold && (staff || !started);
        return [
          if (staff && t.status == TicketStatus.sold)
            IconButton(
              tooltip: 'Отметить как использованный',
              icon: const Icon(Icons.how_to_reg),
              onPressed: () => _change(context, t, TicketStatus.used),
            ),
          if (canReturn)
            IconButton(
              tooltip: 'Вернуть билет',
              icon: const Icon(Icons.undo),
              onPressed: () => _change(context, t, TicketStatus.returned),
            ),
        ];
      },
      filters: (context, q, apply) => [
        ChoiceDropdown(
          label: 'Статус',
          value: q.filter('status'),
          width: 190,
          choices: [for (final s in TicketStatus.values) (value: s.code, label: s.label)],
          onChanged: (value) => apply(q.withFilter('status', value)),
        ),
        ChoiceDropdown(
          label: 'Категория',
          value: q.filter('category'),
          width: 200,
          choices: [for (final c in TicketCategory.values) (value: c.code, label: c.label)],
          onChanged: (value) => apply(q.withFilter('category', value)),
        ),
        ChoiceDropdown(
          label: 'Сеанс',
          value: q.filter('period'),
          width: 190,
          choices: [for (final p in kPeriodChoices.take(2)) p],
          onChanged: (value) => apply(q.withFilter('period', value)),
        ),
      ],
      columns: [
        TableColumnSpec<Ticket>(
          label: 'Сеанс',
          sortField: 'screening',
          build: (t) => CellText(_ticketTitle(t), maxWidth: 300),
        ),
        TableColumnSpec<Ticket>(label: 'Место', build: (t) => Text(t.placeText)),
        TableColumnSpec<Ticket>(
          label: 'Категория',
          hideBelow: 950,
          build: (t) => Text(t.category.label),
        ),
        TableColumnSpec<Ticket>(
          label: 'Цена',
          sortField: 'price',
          numeric: true,
          build: (t) => Text(formatRub(t.price)),
        ),
        TableColumnSpec<Ticket>(label: 'Статус', build: (t) => Text(t.status.label)),
      ],
    );
  }
}
