import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/old_hive_datasource.dart';

class OldWalletRepository {
  final OldHiveDatasource hiveDatasource;

  OldWalletRepository(this.hiveDatasource);

  Future<List<OldWallet>> fetch() async {
    final oldWalletPayload = hiveDatasource.getValue(
      OldStorageKeys.wallets.name,
    );
    if (oldWalletPayload == null) return [];

    final oldWallets = json.decode(oldWalletPayload) as Map<String, dynamic>;
    final walletsIds = oldWallets['wallets'] as List<dynamic>;

    final walletMetadatas = <OldWallet>[];
    for (final walletId in walletsIds) {
      if (walletId is! String) continue;

      final walletMetadata = hiveDatasource.getValue(walletId);
      if (walletMetadata == null) continue;

      final walletMetadataJson =
          json.decode(walletMetadata) as Map<String, dynamic>;
      final walletObj = OldWallet.fromJson(walletMetadataJson);
      walletMetadatas.add(walletObj);
    }

    return walletMetadatas;
  }
}
