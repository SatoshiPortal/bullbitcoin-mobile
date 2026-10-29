import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show BitcoinSyncScriptType;

/// Choices made locally before any wallet history request is permitted.
final class WalletSyncSelection {
  final BitcoinSyncSource source;
  final WalletBirthday? birthday;
  final ScriptType scriptType;
  final BitcoinSyncScriptType? scanScriptType;

  const WalletSyncSelection({
    this.source = BitcoinSyncSource.electrum,
    this.birthday,
    this.scriptType = ScriptType.bip84,
    this.scanScriptType,
  });

  BitcoinSyncScriptType get effectiveScanScriptType =>
      scanScriptType ?? BitcoinSyncScriptType.fromScriptType(scriptType);
}
