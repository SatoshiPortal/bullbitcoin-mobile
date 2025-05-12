import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_bip329.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart'
    show BBNetwork, BaseWalletType, Wallet;
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet_labels.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show Network, ScriptType;
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:flutter/foundation.dart';

Future<List<Bip329Label>> fetchOldLabels(HiveStorage hive) async {
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

      // label.origin is bugged in v0.4.4 do not use it
      // regenerate a correct origin for the current version
      for (final label in [...txsLabels, ...addressesLabels]) {
        final bbNetwork = wallet.network;
        final bbWalletType = wallet.baseWalletType;

        Network? network;
        if (bbNetwork == BBNetwork.Mainnet &&
            bbWalletType == BaseWalletType.Bitcoin) {
          network = Network.bitcoinMainnet;
        } else if (bbNetwork == BBNetwork.Mainnet &&
            bbWalletType == BaseWalletType.Liquid) {
          network = Network.liquidMainnet;
        } else if (bbNetwork == BBNetwork.Testnet &&
            bbWalletType == BaseWalletType.Bitcoin) {
          network = Network.bitcoinTestnet;
        } else if (bbNetwork == BBNetwork.Testnet &&
            bbWalletType == BaseWalletType.Liquid) {
          network = Network.liquidTestnet;
        } else {
          debugPrint('SKIP: unsupported network: $bbNetwork $bbWalletType');
          continue;
        }

        final origin = WalletMetadataService.encodeOrigin(
          fingerprint: wallet.sourceFingerprint,
          network: network,
          scriptType: ScriptType.fromName(wallet.scriptType.name),
        );

        allLabels.add(label.copyWith(origin: origin));
      }
    }
  }

  return allLabels;
}
