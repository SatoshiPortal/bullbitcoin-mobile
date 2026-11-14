import 'package:primitives/primitives.dart';

import 'transaction_sync_failure.dart';
import 'public_wallet_descriptor.dart';
import 'wallet_key.dart';

/// No storage or transport side effects are permitted for an unsupported key.
TransactionSyncFailure? nativeKeyFailure(WalletKey key) {
  switch (key.network) {
    case BitcoinNetwork.mainnet ||
        BitcoinNetwork.testnet ||
        LiquidNetwork.mainnet ||
        LiquidNetwork.testnet:
      return null;
    case BitcoinNetwork.regtest || LiquidNetwork.regtest:
      return key.id.endsWith(':regtest') && key.id.length > ':regtest'.length
          ? null
          : const TransactionSyncInvalidCatalogFailure();
    case BitcoinNetwork.signet:
      return const TransactionSyncUnsupportedNetworkFailure();
  }
}

/// Regtest is deliberately limited to native witness receive AND change.
/// Native parsing subsequently validates descriptor syntax before any persist.
TransactionSyncFailure? nativeDescriptorFailure(PublicWalletDescriptor value) {
  final keyFailure = nativeKeyFailure(value.key);
  if (keyFailure != null) return keyFailure;
  if (value.key.network != BitcoinNetwork.regtest) return null;
  if (value is! BitcoinWalletDescriptor ||
      value.scriptType != ScriptType.bip84 ||
      !value.externalDescriptor.startsWith('wpkh(') ||
      !value.internalDescriptor.startsWith('wpkh(')) {
    return const TransactionSyncInvalidCatalogFailure();
  }
  return null;
}
