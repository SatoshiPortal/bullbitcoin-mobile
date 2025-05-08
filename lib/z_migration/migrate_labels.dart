import 'dart:convert';

import 'package:bb_mobile/z_migration/migrations.dart'
    show HiveStorage, StorageKeys;
import 'package:bb_mobile/z_migration/old_bip329.dart';
import 'package:bb_mobile/z_migration/old_wallet.dart' show Wallet;
import 'package:bb_mobile/z_migration/old_wallet_labels.dart' show WalletLabels;

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
