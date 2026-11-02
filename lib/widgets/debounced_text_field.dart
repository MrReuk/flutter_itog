import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.delay = const Duration(milliseconds: 300),
    this.keyboardType,
    this.inputFormatters,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final Duration delay;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  Timer? _timer;

  @override
  void didUpdateWidget(DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final typing = _timer?.isActive ?? false;
    if (widget.value != oldWidget.value && widget.value != _controller.text && !typing) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  void _handleChanged(String text) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () => widget.onChanged(text));
  }

  void _handleSubmitted(String text) {
    _timer?.cancel();
    widget.onChanged(text);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: _handleChanged,
      onSubmitted: _handleSubmitted,
    );
  }
}
