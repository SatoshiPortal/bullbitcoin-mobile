import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter/widgets.dart';

typedef OpenSignedTransactionReader = Future<void> Function(
  BuildContext context,
  String unsignedPsbt,
  Wallet? wallet,
);

/// The shell supplies the destination; Send retains the original transaction.
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
