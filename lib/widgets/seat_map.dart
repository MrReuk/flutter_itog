import 'package:flutter/material.dart';

enum SeatState { free, taken, chosen }

class SeatMap extends StatelessWidget {
  const SeatMap({
    super.key,
    required this.rows,
    required this.seatsPerRow,
    required this.stateOf,
    required this.onTap,
  });

  final int rows;
  final int seatsPerRow;
  final SeatState Function(int row, int seat) stateOf;
  final void Function(int row, int seat) onTap;

  static const double _minCell = 30;
  static const double _maxCell = 44;
  static const double _labelWidth = 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _labelWidth;
        final fit = seatsPerRow == 0 ? _maxCell : available / seatsPerRow;
        final cell = fit.clamp(_minCell, _maxCell).toDouble();
        final gridWidth = _labelWidth + cell * seatsPerRow;

        return Column(
          children: [
            _Screen(width: gridWidth > constraints.maxWidth ? gridWidth : constraints.maxWidth),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  for (var row = 1; row <= rows; row++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _labelWidth,
                          child: Text(
                            '$row',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        for (var seat = 1; seat <= seatsPerRow; seat++)
                          _SeatButton(
                            key: ValueKey('seat-$row-$seat'),
                            size: cell,
                            label: '$seat',
                            state: stateOf(row, seat),
                            scheme: scheme,
                            onTap: () => onTap(row, seat),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _LegendItem(
                  color: scheme.surfaceContainerHighest,
                  label: 'Свободно',
                  scheme: scheme,
                ),
                _LegendItem(color: scheme.primary, label: 'Выбрано', scheme: scheme),
                _LegendItem(
                  color: scheme.outlineVariant,
                  label: 'Занято',
                  scheme: scheme,
                  crossed: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 8,
      width: width * 0.7,
      decoration: BoxDecoration(
        color: scheme.outline,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      alignment: Alignment.center,
      child: const SizedBox.shrink(),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    super.key,
    required this.size,
    required this.label,
    required this.state,
    required this.scheme,
    required this.onTap,
  });

  final double size;
  final String label;
  final SeatState state;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (state) {
      SeatState.free => (scheme.surfaceContainerHighest, scheme.onSurface),
      SeatState.chosen => (scheme.primary, scheme.onPrimary),
      SeatState.taken => (scheme.outlineVariant, scheme.outline),
    };
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: true,
        enabled: state != SeatState.taken,
        selected: state == SeatState.chosen,
        label:
            'Место $label, ${switch (state) {
              SeatState.free => 'свободно',
              SeatState.chosen => 'выбрано',
              SeatState.taken => 'занято',
            }}',
        child: InkWell(
          onTap: state == SeatState.taken ? null : onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: size - 4,
            height: size - 4,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
            child: ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: foreground,
                  decoration: state == SeatState.taken ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.scheme,
    this.crossed = false,
  });

  final Color color;
  final String label;
  final ColorScheme scheme;
  final bool crossed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
