import 'package:flutter/material.dart';

/// A reorderable list with an optional fixed header.
class BullReorderableList extends StatelessWidget {
  const BullReorderableList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorderItem,
    this.onReorderStart,
    this.header,
    this.padding,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ReorderCallback onReorderItem;
  final ValueChanged<int>? onReorderStart;
  final Widget? header;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    onReorderItem: onReorderItem,
    onReorderStart: onReorderStart,
    header: header,
    padding: padding,
    buildDefaultDragHandles: false,
  );
}

/// Starts a reorder after a long press.
class BullReorderHandle extends StatelessWidget {
  const BullReorderHandle({
    super.key,
    required this.index,
    required this.child,
    this.enabled = true,
  });
  final int index;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ReorderableDelayedDragStartListener(
    index: index,
    enabled: enabled,
    child: child,
  );
}
