import 'package:transaction_sync/transaction_sync.dart';

/// Compatibility bridge for legacy throwing consumers. The modeled failure is preserved without copying native messages into logs or user-facing strings.
final class BitcoinSyncOperationException implements Exception {
  final WalletTransactionSyncFailure failure;

  const BitcoinSyncOperationException(this.failure);

  @override
  String toString() => 'Bitcoin synchronization operation unavailable';
}
