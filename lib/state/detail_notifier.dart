import 'package:flutter/foundation.dart';

import 'load_status.dart';
import 'paged_list_notifier.dart';

class DetailNotifier<T> extends ChangeNotifier {
  DetailNotifier(this._loader);

  final Future<T?> Function() _loader;

  LoadStatus _status = LoadStatus.idle;
  T? _item;
  String? _error;
  bool _disposed = false;

  LoadStatus get status => _status;
  T? get item => _item;
  String? get error => _error;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _item = await _loader();
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить запись: ${describeError(e)}';
      _status = LoadStatus.error;
    }
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
