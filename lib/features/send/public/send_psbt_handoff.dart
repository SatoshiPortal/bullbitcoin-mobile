import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:spend/spend.dart';

typedef OpenSignedTransactionReader = Future<String?> Function(
  BuildContext context,
  PreparedBitcoinSpend prepared,
  BitcoinNetwork network,
);

/// The reader returns verified bytes without broadcasting them.
class SendPsbtHandoff extends InheritedWidget {
  final OpenSignedTransactionReader openReader;

  const SendPsbtHandoff({
    super.key,
    required this.openReader,
    required super.child,
  });

  static OpenSignedTransactionReader of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SendPsbtHandoff>();
    if (scope == null) throw StateError('Send PSBT handoff is not configured');
    return scope.openReader;
  }

  @override
  bool updateShouldNotify(SendPsbtHandoff oldWidget) =>
      openReader != oldWidget.openReader;
}
