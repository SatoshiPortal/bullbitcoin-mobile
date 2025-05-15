import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:flutter/foundation.dart';

class MigrateSeedToV5AndGetHiveToSqliteWalletsUsecase {
  final NewSeedRepository _newSeedRepository;
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;
  MigrateSeedToV5AndGetHiveToSqliteWalletsUsecase({
    required NewSeedRepository newSeedRepository,
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
  }) : _newSeedRepository = newSeedRepository,
       _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository;

  Future<List<OldWallet>?> execute() async {
    try {
      final oldWallets = await _oldWalletRepository.fetch();
      if (oldWallets.isEmpty) return [];
      final oldFingerprints =
          oldWallets.map((e) => e.mnemonicFingerprint).toSet().toList();
      debugPrint('oldFingerprints: ${oldFingerprints.length}');
      final mainWallets =
          oldWallets.where((e) => e.type == OldBBWalletType.main).toList();
      debugPrint('mainWallets: ${mainWallets.length}');
      final externalWallets =
          oldWallets.where((e) => e.type != OldBBWalletType.main).toList();
      debugPrint('externalWallets: ${externalWallets.length}');
      // toSet().toList() removes duplicates
      // main wallets share the same seed/fingerprint
      final seedsImported = await _storeNewSeeds(oldFingerprints);
      debugPrint(
        'migration: ${seedsImported.length}/${oldFingerprints.length} seeds',
      );

      return oldWallets;
    } catch (e) {
      debugPrint('migration failed: $e');
      return null;
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

  // TODO: Handle passphrase wallets
  // ignore: unused_element
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
