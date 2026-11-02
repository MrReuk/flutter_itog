import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../widgets/auth_frame.dart';
import '../widgets/state_views.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(kAutoRetryInterval, (_) {
      if (!_busy) _retry();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    final auth = context.read<AuthNotifier>();
    setState(() => _busy = true);
    try {
      await auth.restore();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Сервер недоступен',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Не удалось проверить вашу сессию: сервер не отвечает. '
            'Вы не вышли из системы, сессия сохранена. '
            'Связь проверяется автоматически каждые 5 секунд.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await context.read<AuthNotifier>().logout();
                    if (context.mounted) context.go('/login');
                  },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
