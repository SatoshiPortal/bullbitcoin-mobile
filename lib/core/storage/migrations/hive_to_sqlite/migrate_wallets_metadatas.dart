import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart';

List<OldWallet> fetchOldWalletMetadatas(OldHiveStorage hive) {
  final oldWalletPayload = hive.getValue(OldStorageKeys.wallets.name);
  final oldWallets = json.decode(oldWalletPayload!) as Map<String, dynamic>;
  final walletsIds = oldWallets['wallets'] as List<dynamic>;

  final walletMetadatas = <OldWallet>[];
  for (final walletId in walletsIds) {
    if (walletId is! String) continue;

    final walletMetadata = hive.getValue(walletId);
    if (walletMetadata == null) continue;

    final walletMetadataJson =
        json.decode(walletMetadata) as Map<String, dynamic>;
    final walletObj = OldWallet.fromJson(walletMetadataJson);
    walletMetadatas.add(walletObj);
  }

  return walletMetadatas;
}
