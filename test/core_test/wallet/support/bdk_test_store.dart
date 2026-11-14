import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart'
    show NetworkX;

import 'dart:io';

import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:path_provider/path_provider.dart';

/// Native fixture construction belongs to tests, never production readers.
abstract final class BdkTestStore {
  static Future<String> _path(String hexId) async =>
      '${(await getApplicationDocumentsDirectory()).path}/${hexId}_bdk_dart';

  static Future<bdk.Wallet> createWallet(WalletModel model) async {
    if (model is! PublicBdkWalletModel) {
      throw ArgumentError('Expected BDK fixture');
    }
    final path = await _path(model.hexId);
    final exists = File(path).existsSync();
    final kind = model.network.isMainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
    final external = bdk.Descriptor(
      descriptor: model.externalDescriptor,
      networkKind: kind,
    );
    final internal = bdk.Descriptor(
      descriptor: model.internalDescriptor,
      networkKind: kind,
    );
    final persister = bdk.Persister.newSqlite(path: path);
    try {
      return exists
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: persister,
              lookahead: 25,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: model.network.bdkNetwork,
              persister: persister,
              lookahead: 25,
            );
    } finally {
      persister.dispose();
      external.dispose();
      internal.dispose();
    }
  }

  static Future<void> saveWallet(bdk.Wallet wallet, String hexId) async {
    final persister = bdk.Persister.newSqlite(path: await _path(hexId));
    try {
      wallet.persist(persister: persister);
    } finally {
      persister.dispose();
    }
  }
}
