import 'package:flutter/material.dart';

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionWidth = 120,
    this.stackBelow = 520,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? action;

  final double actionWidth;

  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = action != null && constraints.maxWidth < stackBelow;
          final tile = ListTile(
            leading: leading,
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitle),
            isThreeLine: subtitle.contains('\n'),
            trailing: action != null && !stacked
                ? SizedBox(
                    width: actionWidth,
                    child: Align(alignment: Alignment.centerRight, child: action),
                  )
                : null,
          );
          if (!stacked) return tile;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(alignment: Alignment.centerRight, child: action),
              ),
            ],
          );
        },
      ),
    );
  }
}
