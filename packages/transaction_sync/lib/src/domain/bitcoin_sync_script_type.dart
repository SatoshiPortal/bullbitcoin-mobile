import 'package:primitives/primitives.dart' show ScriptType;

import 'bitcoin_sync_checkpoint.dart';

/// Earliest possible history for an HD wallet's output script, independent of
/// key origin paths (a descriptor's script can differ from its BIP purpose).
enum BitcoinSyncScriptType {
  taproot,
  segwitV0,
  preSegwit;

  factory BitcoinSyncScriptType.fromScriptType(ScriptType scriptType) =>
      switch (scriptType) {
        ScriptType.bip84 || ScriptType.bip49 => segwitV0,
        ScriptType.bip44 => preSegwit,
      };

  /// Classifies an already validated public descriptor. Unrecognized scripts
  /// conservatively retain the entire supported HD-wallet history.
  factory BitcoinSyncScriptType.fromDescriptor(String descriptor) {
    final script = descriptor.replaceAll(RegExp(r'\s+'), '');
    if (script.startsWith('tr(')) return taproot;
    if (script.startsWith('wpkh(') ||
        script.startsWith('wsh(') ||
        script.startsWith('sh(wpkh(') ||
        script.startsWith('sh(wsh(')) {
      return segwitV0;
    }
    return preSegwit;
  }

  BitcoinSyncCheckpoint get floor => switch (this) {
    taproot => BitcoinSyncCheckpoint.taproot,
    segwitV0 => BitcoinSyncCheckpoint.segwit,
    preSegwit => BitcoinSyncCheckpoint.bip32,
  };

  /// Policy start date, distinct from the preceding checkpoint's header time.
  /// P2PKH predates BIP32; February 2012 is the HD-wallet support floor.
  DateTime get earliestDate => switch (this) {
    taproot => DateTime.utc(2021, 11, 14),
    segwitV0 => DateTime.utc(2017, 8, 24),
    preSegwit => DateTime.utc(2012, 2, 1),
  };
}
