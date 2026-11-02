import 'package:flutter/widgets.dart';

enum ScreenSize { compact, medium, expanded }

const double kMediumBreakpoint = 600;

const double kExpandedBreakpoint = 1200;

const double kTableMinWidth = 760;

const double kContentMaxWidth = 1280;

ScreenSize screenSizeForWidth(double width) {
  if (width < kMediumBreakpoint) return ScreenSize.compact;
  if (width < kExpandedBreakpoint) return ScreenSize.medium;
  return ScreenSize.expanded;
}

ScreenSize screenSizeOf(BuildContext context) {
  return screenSizeForWidth(MediaQuery.sizeOf(context).width);
}

T byScreen<T>(BuildContext context, {required T compact, T? medium, T? expanded}) {
  return pickByScreen(screenSizeOf(context), compact: compact, medium: medium, expanded: expanded);
}

T pickByScreen<T>(ScreenSize size, {required T compact, T? medium, T? expanded}) {
  return switch (size) {
    ScreenSize.compact => compact,
    ScreenSize.medium => medium ?? compact,
    ScreenSize.expanded => expanded ?? medium ?? compact,
  };
}

int gridColumns(double width, {required double minTile, double spacing = 12}) {
  if (width <= 0 || minTile <= 0) return 1;
  final columns = ((width + spacing) / (minTile + spacing)).floor();
  return columns < 1 ? 1 : columns;
}
