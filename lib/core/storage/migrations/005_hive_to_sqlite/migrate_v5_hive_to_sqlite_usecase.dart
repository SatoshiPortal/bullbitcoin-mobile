import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/tables/v5_migrate_wallet_metadata_table.dart';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:flutter/foundation.dart';

class MigrateToV5HiveToSqliteToUsecase {
  final NewSeedRepository _newSeedRepository;
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;
  final NewWalletRepository _newWalletRepository;
  MigrateToV5HiveToSqliteToUsecase({
    required NewSeedRepository newSeedRepository,
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
    required NewWalletRepository newWalletRepository,
  }) : _newSeedRepository = newSeedRepository,
       _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository,
       _newWalletRepository = newWalletRepository;

  Future<bool> execute() async {
    try {
      final oldWallets = await _oldWalletRepository.fetch();
      final mainWallets =
          oldWallets.where((e) => e.type == OldBBWalletType.main).toList();
      debugPrint('mainWallets: ${mainWallets.length}');
      final externalWallets =
          oldWallets.where((e) => e.type != OldBBWalletType.main).toList();
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

      await _storeMainWallets(mainWallets);
      await _storeExternalWallet(externalWallets);
      return true;
    } catch (e) {
      debugPrint('migration failed: $e');
      return false;
    }
  }

  Future<List<NewSeedEntity>> _storeNewSeeds(
    List<String> oldFingerprints,
  ) async {
    final List<NewSeedEntity> seeds = [];

    for (final oldFingerprint in oldFingerprints) {
      try {
        final oldSeed = await _oldSeedRepository.fetch(
          fingerprint: oldFingerprint,
        );
        final hasPassphrase = oldSeed.passphrases.isNotEmpty;
        if (hasPassphrase) {
          for (final passphrase in oldSeed.passphrases) {
            final seed = NewSeedEntity.mnemonic(
              mnemonicWords: oldSeed.mnemonicList(),
              passphrase: passphrase.passphrase,
            );
            await _newSeedRepository.store(
              fingerprint: seed.masterFingerprint,
              seed: seed,
            );
            seeds.add(seed);
          }
        }
        final seed = NewSeedEntity.mnemonic(
          mnemonicWords: oldSeed.mnemonicList(),
        );
        await _newSeedRepository.store(
          fingerprint: seed.masterFingerprint,
          seed: seed,
        );
        seeds.add(seed);
      } catch (e) {
        debugPrint('SKIP: $e');
      }
    }
    return seeds;
  }

  Future<void> _storeMainWallets(List<OldWallet> oldMainWallets) async {
    // fetch main wallet seed by fingerprint
    final mainWalletSeed = await _newSeedRepository.fetch(
      fingerprint: oldMainWallets.first.mnemonicFingerprint,
    );
    int count = 0;
    for (final oldWallet in oldMainWallets) {
      final network =
          oldWallet.baseWalletType == OldBaseWalletType.Bitcoin
              ? (oldWallet.isTestnet()
                  ? NewNetwork.bitcoinTestnet
                  : NewNetwork.bitcoinMainnet)
              : (oldWallet.isTestnet()
                  ? NewNetwork.liquidTestnet
                  : NewNetwork.liquidMainnet);

      final scriptType = switch (oldWallet.scriptType) {
        OldScriptType.bip84 => NewScriptType.bip84,
        OldScriptType.bip49 => NewScriptType.bip49,
        OldScriptType.bip44 => NewScriptType.bip44,
      };
      final id = await _newWalletRepository.createWalletMetadata(
        seed: mainWalletSeed,
        scriptType: scriptType,
        network: network,
        isDefault: true,
      );
      count++;
      debugPrint('Created Default Wallet: $id');
      // TODO: Store newWallet in the new database
    }
    debugPrint('Recovered $count/${oldMainWallets.length} main wallets');
  }

  // TODO: Handle passphrase wallets
  Future<void> _storeExternalWallet(List<OldWallet> oldExternalWallets) async {
    int count = 0;

    for (final oldExternalWallet in oldExternalWallets) {
      final newExternalSeed = await _newSeedRepository.fetch(
        fingerprint: oldExternalWallet.mnemonicFingerprint,
      );
      final network =
          oldExternalWallet.baseWalletType == OldBaseWalletType.Bitcoin
              ? (oldExternalWallet.isTestnet()
                  ? NewNetwork.bitcoinTestnet
                  : NewNetwork.bitcoinMainnet)
              : (oldExternalWallet.isTestnet()
                  ? NewNetwork.liquidTestnet
                  : NewNetwork.liquidMainnet);

      final scriptType = switch (oldExternalWallet.scriptType) {
        OldScriptType.bip84 => NewScriptType.bip84,
        OldScriptType.bip49 => NewScriptType.bip49,
        OldScriptType.bip44 => NewScriptType.bip44,
      };

      final source = switch (oldExternalWallet.type) {
        OldBBWalletType.main => NewWalletSource.mnemonic,
        OldBBWalletType.coldcard => NewWalletSource.coldcard,
        OldBBWalletType.xpub => NewWalletSource.xpub,
        OldBBWalletType.words => NewWalletSource.mnemonic,
        OldBBWalletType.descriptors => NewWalletSource.descriptors,
      };

      // ignore: unused_local_variable
      if (source == NewWalletSource.mnemonic) {
        final id = await _newWalletRepository.createWalletMetadata(
          seed: newExternalSeed,
          scriptType: scriptType,
          network: network,
          label: oldExternalWallet.name ?? oldExternalWallet.sourceFingerprint,
        );
        count++;
        debugPrint('Created External Mnemonic Wallet: $id');
      }
    }
    debugPrint(
      'Recovered $count/ ${oldExternalWallets.length} external wallets',
    );

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
