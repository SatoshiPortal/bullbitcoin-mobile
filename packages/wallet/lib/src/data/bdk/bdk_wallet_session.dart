import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:transaction_sync/transaction_sync.dart';

/// Owns a native wallet and its persister for one coordinated operation.
final class BdkWalletSession {
  final bdk.Wallet wallet;
  final bdk.Persister persister;

  BdkWalletSession._(this.wallet, this.persister);

  static Future<BdkWalletSession> open(
    BdkElectrumConfiguration configuration,
    File file, {
    required bool create,
  }) async {
    final existed = await file.exists();
    // The persister must outlive the wallet: the uniffi Wallet object keeps
    // using it, so both handles are owned and released together.
    final persister = bdk.Persister.newSqlite(path: file.path);
    bdk.Descriptor? external;
    bdk.Descriptor? internal;
    try {
      external = bdk.Descriptor(
        descriptor: configuration.externalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      internal = bdk.Descriptor(
        descriptor: configuration.internalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      final wallet = openPersistedWallet(
        external: external,
        internal: internal,
        persister: persister,
        load: !create || existed,
        network: configuration.isTestnet
            ? bdk.Network.testnet
            : bdk.Network.bitcoin,
        lookahead: configuration.stopGap,
      );
      return BdkWalletSession._(wallet, persister);
    } catch (_) {
      persister.dispose();
      rethrow;
    } finally {
      internal?.dispose();
      external?.dispose();
    }
  }

  /// The caller owns descriptors and the persister if construction fails.
  static bdk.Wallet openPersistedWallet({
    required bdk.Descriptor external,
    required bdk.Descriptor internal,
    required bdk.Persister persister,
    required bool load,
    required bdk.Network network,
    required int lookahead,
  }) => load
      ? bdk.Wallet.load(
          descriptor: external,
          changeDescriptor: internal,
          persister: persister,
          lookahead: lookahead,
        )
      : bdk.Wallet(
          descriptor: external,
          changeDescriptor: internal,
          network: network,
          persister: persister,
          lookahead: lookahead,
        );

  void dispose() {
    try {
      wallet.dispose();
    } finally {
      persister.dispose();
    }
  }
}
