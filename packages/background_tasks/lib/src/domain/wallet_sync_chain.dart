import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

enum WalletSyncChain { bitcoin, liquid }

WalletSyncChain walletSyncChain(WalletKey key) => switch (key.network) {
  BitcoinNetwork() => WalletSyncChain.bitcoin,
  LiquidNetwork() => WalletSyncChain.liquid,
};
