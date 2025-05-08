import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_bip329.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet_labels.dart';

Future<List<Bip329Label>> fetchLabels(HiveStorage hive) async {
  final oldWalletsPayload = hive.getValue(StorageKeys.wallets.name) ?? '{}';
  final oldWallets = json.decode(oldWalletsPayload) as Map<String, dynamic>;

  final walletIds = oldWallets['wallets'] as List? ?? [];

  final allLabels = <Bip329Label>[];
  for (final id in walletIds) {
    if (id is String) {
      final v = hive.getValue(id);
      if (v == null) continue;

      final obj = json.decode(v) as Map<String, dynamic>;
      final wallet = Wallet.fromJson(obj);

      final txsLabels = await WalletLabels.txsToBip329(
        wallet.transactions,
        wallet.originString(),
      );

      final addressesLabels = await WalletLabels.addressesToBip329(
        wallet.myAddressBook,
        wallet.originString(),
      );

      allLabels.addAll([...txsLabels, ...addressesLabels]);
    }
  }

  return allLabels;
}
