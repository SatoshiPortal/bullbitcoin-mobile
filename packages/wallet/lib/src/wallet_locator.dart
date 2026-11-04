import 'package:transaction_sync/transaction_sync.dart';

import 'data/bdk/bdk_wallet_transaction_source.dart';
import 'data/lwk/lwk_wallet_transaction_source.dart';

/// Constructs native sources without exposing their SDK implementations.
abstract final class WalletLocator {
  static WalletTransactionSourcePort bdkElectrum({
    WalletCoordinationLogSink? logSink,
  }) => BdkWalletTransactionSource(logSink: logSink);

  static WalletTransactionSourcePort lwkElectrum({
    WalletCoordinationLogSink? logSink,
  }) => LwkWalletTransactionSource(logSink: logSink);
}
