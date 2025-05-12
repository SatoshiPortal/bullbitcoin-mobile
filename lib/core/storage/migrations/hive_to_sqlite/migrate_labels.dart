import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_utils.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_bip329.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart'
    show OldWallet;
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet_labels.dart';
import 'package:flutter/foundation.dart';

Future<List<OldBip329Label>> fetchOldLabels(OldHiveStorage hive) async {
  final oldWalletsPayload = hive.getValue(OldStorageKeys.wallets.name) ?? '{}';
  final oldWallets = json.decode(oldWalletsPayload) as Map<String, dynamic>;

  final walletIds = oldWallets['wallets'] as List? ?? [];

  final allLabels = <OldBip329Label>[];
  for (final id in walletIds) {
    if (id is String) {
      final v = hive.getValue(id);
      if (v == null) continue;

      final obj = json.decode(v) as Map<String, dynamic>;
      final wallet = OldWallet.fromJson(obj);

      final txsLabels = await WalletLabels.txsToBip329(
        wallet.transactions,
        wallet.originString(),
      );

      final addressesLabels = await WalletLabels.addressesToBip329(
        wallet.myAddressBook,
        wallet.originString(),
      );

      // label.origin is bugged in v0.4.4 do not use it
      // regenerate a correct origin for the current version
      for (final label in [...txsLabels, ...addressesLabels]) {
        try {
          final origin = computeOriginFromOldWallet(wallet);
          allLabels.add(label.copyWith(origin: origin));
        } catch (e) {
          debugPrint('SKIP: $e');
          continue;
        }
      }
    }
  }

  return allLabels;
}
