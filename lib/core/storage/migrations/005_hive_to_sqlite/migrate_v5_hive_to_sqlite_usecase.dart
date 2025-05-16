import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/foundation.dart';

class MigrateToV5HiveToSqliteToUsecase {
  final SeedRepository _newSeedRepository;
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;
  final WalletRepository _newWalletRepository;
  MigrateToV5HiveToSqliteToUsecase({
    required SeedRepository newSeedRepository,
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
    required WalletRepository newWalletRepository,
  }) : _newSeedRepository = newSeedRepository,
       _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository,
       _newWalletRepository = newWalletRepository;
  // true : successful migration
  // false: migration was not required / success
  // throw: errors
  Future<bool> execute() async {
    try {
      final oldWallets = await _oldWalletRepository.fetch();
      final oldMainnetWallets =
          oldWallets.where((e) => e.network == OldBBNetwork.Mainnet).toList();
      final newMainnetWallets = await _newWalletRepository.getWallets(
        environment: Environment.mainnet,
      );
      if (oldMainnetWallets.length == newMainnetWallets.length) return false;

      final mainWallets =
          oldWallets
              .where(
                (e) =>
                    e.type == OldBBWalletType.main &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();
      debugPrint('mainWallets: ${mainWallets.length}');
      final externalWallets =
          oldWallets
              .where(
                (e) =>
                    e.type != OldBBWalletType.main &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();
      debugPrint('externalWallets: ${externalWallets.length}');
      // toSet().toList() removes duplicates
      // main wallets share the same seed/fingerprint
      final oldFingerprints =
          oldWallets.map((e) => e.mnemonicFingerprint).toSet().toList();
      debugPrint('oldFingerprints: ${oldFingerprints.length}');
      if (oldFingerprints.isEmpty) return false;
      final seedsImported = await _storeNewSeeds(oldFingerprints);
      debugPrint(
        'migration: ${seedsImported.length}/${oldFingerprints.length} seeds',
      );

      final mainCount = await _storeMainWallets(mainWallets);
      final finalExternalCount = await _storeExternalWallet(externalWallets);

      debugPrint(
        'migration: $mainCount/${mainWallets.length} main wallets and $finalExternalCount/${externalWallets.length} external wallets',
      );
      return true;
    } catch (e) {
      debugPrint('migration failed: $e');
      return false;
    }
  }

  Future<List<MnemonicSeed>> _storeNewSeeds(
    List<String> oldFingerprints,
  ) async {
    final List<MnemonicSeed> seeds = [];

    for (final oldFingerprint in oldFingerprints) {
      try {
        final oldSeed = await _oldSeedRepository.fetch(
          fingerprint: oldFingerprint,
        );
        final hasPassphrase = oldSeed.passphrases.isNotEmpty;
        if (hasPassphrase) {
          for (final passphrase in oldSeed.passphrases) {
            final seed = await _newSeedRepository.createFromMnemonic(
              mnemonicWords: oldSeed.mnemonicList(),
              passphrase: passphrase.passphrase,
            );
            seeds.add(seed);
          }
        }
        final seed = await _newSeedRepository.createFromMnemonic(
          mnemonicWords: oldSeed.mnemonicList(),
        );
        seeds.add(seed);
      } catch (e) {
        debugPrint('SKIP: $e');
      }
    }
    return seeds;
  }

  Future<int> _storeMainWallets(List<OldWallet> oldMainWallets) async {
    try {
      int count = 0;
      final mainWalletSeed = await _newSeedRepository.get(
        oldMainWallets.first.mnemonicFingerprint,
      );

      for (final oldWallet in oldMainWallets) {
        final network =
            oldWallet.baseWalletType == OldBaseWalletType.Bitcoin
                ? (oldWallet.isTestnet()
                    ? Network.bitcoinTestnet
                    : Network.bitcoinMainnet)
                : (oldWallet.isTestnet()
                    ? Network.liquidTestnet
                    : Network.liquidMainnet);

        final scriptType = switch (oldWallet.scriptType) {
          OldScriptType.bip84 => ScriptType.bip84,
          OldScriptType.bip49 => ScriptType.bip49,
          OldScriptType.bip44 => ScriptType.bip44,
        };

        await _newWalletRepository.createWallet(
          seed: mainWalletSeed,
          scriptType: scriptType,
          network: network,
          isDefault: true,
        );
        count++;
        // TODO: Store newWallet in the new database
      }
      return count;
    } catch (e) {
      debugPrint('migration failed: $e');
      return 0;
    }
  }

  // TODO: Handle passphrase wallets
  Future<int> _storeExternalWallet(List<OldWallet> oldExternalWallets) async {
    int count = 0;
    for (final oldExternalWallet in oldExternalWallets) {
      final newExternalSeed = await _newSeedRepository.get(
        oldExternalWallet.sourceFingerprint,
      );
      final network =
          oldExternalWallet.baseWalletType == OldBaseWalletType.Bitcoin
              ? (oldExternalWallet.isTestnet()
                  ? Network.bitcoinTestnet
                  : Network.bitcoinMainnet)
              : (oldExternalWallet.isTestnet()
                  ? Network.liquidTestnet
                  : Network.liquidMainnet);

      final scriptType = switch (oldExternalWallet.scriptType) {
        OldScriptType.bip84 => ScriptType.bip84,
        OldScriptType.bip49 => ScriptType.bip49,
        OldScriptType.bip44 => ScriptType.bip44,
      };

      final source = switch (oldExternalWallet.type) {
        OldBBWalletType.main => WalletSource.mnemonic,
        OldBBWalletType.coldcard => WalletSource.coldcard,
        OldBBWalletType.xpub => WalletSource.xpub,
        OldBBWalletType.words => WalletSource.mnemonic,
        OldBBWalletType.descriptors => WalletSource.descriptors,
      };

      // ignore: unused_local_variable
      if (source == WalletSource.mnemonic) {
        await _newWalletRepository.createWallet(
          seed: newExternalSeed,
          scriptType: scriptType,
          network: network,
          isDefault: true,
        );
      }
      count++;
    }
    return count;
    // TODO: Store newWallet in the new database
  }
}

extension ScriptTypeX on NewScriptType {
  XpubType getXpubType(NewNetwork network) {
    if (network.isMainnet) {
      switch (this) {
        case NewScriptType.bip44:
          return XpubType.xpub;
        case NewScriptType.bip49:
          return XpubType.ypub;
        case NewScriptType.bip84:
          return XpubType.zpub;
      }
    } else {
      switch (this) {
        case NewScriptType.bip44:
          return XpubType.tpub;
        case NewScriptType.bip49:
          return XpubType.upub;
        case NewScriptType.bip84:
          return XpubType.vpub;
      }
    }
  }
}
