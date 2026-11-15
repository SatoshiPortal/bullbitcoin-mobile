import 'package:flutter/widgets.dart';

/// Renders an observable value without exposing loading snapshots to consumers.
/// Typed application state owns loading and failure presentation.
class BullStreamValueBuilder<T extends Object> extends StatelessWidget {
  const BullStreamValueBuilder({
    super.key,
    required this.stream,
    required this.initialValue,
    required this.builder,
  });
  final Stream<T> stream;
  final T initialValue;
  final Widget Function(BuildContext, T) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    key: ObjectKey(stream),
    stream: stream,
    initialData: initialValue,
    builder: (context, snapshot) =>
        builder(context, snapshot.data ?? initialValue),
  );
}
