import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:transaction_sync/transaction_sync.dart'
    show BitcoinSyncSource, BitcoinSyncScriptType;

/// Local preferences only; reading these never opens a wallet network source.
final class WalletSyncSettings {
  final String walletId;
  final bool isLiquid;
  final BitcoinNetwork network;
  final BitcoinSyncSource source;
  final DateTime? birthday;
  final BitcoinSyncScriptType scanScriptType;

  const WalletSyncSettings({
    required this.walletId,
    required this.isLiquid,
    required this.network,
    required this.source,
    required this.birthday,
    this.scanScriptType = BitcoinSyncScriptType.segwitV0,
  });
}
