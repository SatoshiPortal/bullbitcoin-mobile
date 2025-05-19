import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/foundation.dart';

class MigrateToV5HiveToSqliteToUsecase {
  final SeedRepository _newSeedRepository;
  final WalletRepository _newWalletRepository;

  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;
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
      if (oldWallets.isEmpty) return false;

      final newMainnetDefaultWallets = await _newWalletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      );
      if (newMainnetDefaultWallets.length == 2) return false;

      final oldMainnetDefaultWallets =
          oldWallets
              .where(
                (e) =>
                    e.type == OldBBWalletType.main &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();
      debugPrint('defaultOldSignerWallets: ${oldMainnetDefaultWallets.length}');
      final oldMainnetExternalSignerWallets =
          oldWallets
              .where(
                (e) =>
                    e.type == OldBBWalletType.words &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();

      final oldMainnetWatchOnlyWallets =
          oldWallets
              .where(
                (e) =>
                    ((e.type == OldBBWalletType.xpub) ||
                        (e.type == OldBBWalletType.coldcard)) &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();

      debugPrint(
        'externalOldSignerWallets: ${oldMainnetExternalSignerWallets.length}',
      );

      final oldMainnetSignerWallets =
          oldMainnetDefaultWallets + oldMainnetExternalSignerWallets;

      final seedsImported = await _storeNewSeeds(oldMainnetSignerWallets);
      debugPrint(
        'migration: ${seedsImported.length}/${oldMainnetSignerWallets.length} seeds',
      );
      if (seedsImported.isEmpty) return false;
      final mainCount = await _storeMainWallets(oldMainnetDefaultWallets);
      final finalExternalCount = await _storeExternalWallet(
        oldMainnetExternalSignerWallets,
      );
      final finalWatchOnlyCount = await _storeWatchOnlyWallet(
        oldMainnetWatchOnlyWallets,
      );
      debugPrint(
        'migration completed: ${seedsImported.length} seeds, $mainCount/${oldMainnetDefaultWallets.length} default wallets\n$finalExternalCount/${oldMainnetExternalSignerWallets.length} external wallets\n$finalWatchOnlyCount/${oldMainnetWatchOnlyWallets.length} watch only wallets;\nSuccessfully migrated ${mainCount + finalExternalCount + finalWatchOnlyCount} wallets',
      );
      return true;
    } catch (e) {
      debugPrint('migration failed: $e');
      return false;
    }
  }

  Future<List<MnemonicSeed>> _storeNewSeeds(List<OldWallet> oldWallets) async {
    try {
      // mnemonic fingerprints are seed indexes
      // source fingerprints are passphrase indexes
      // mnemonic == source fingerprint for wallets without passphrases

      final List<MnemonicSeed> seeds = [];
      for (final oldWallet in oldWallets) {
        final oldSeed = await _oldSeedRepository.fetch(
          fingerprint: oldWallet.mnemonicFingerprint,
        );
        if (oldWallet.hasPassphrase()) {
          final oldPassphrase = oldSeed.getPassphraseFromIndex(
            oldWallet.sourceFingerprint,
          );
          final seed = await _newSeedRepository.createFromMnemonic(
            mnemonicWords: oldSeed.mnemonicList(),
            passphrase: oldPassphrase.passphrase,
          );
          seeds.add(seed);
          debugPrint(
            'Imported seed w/passphrase: ${oldWallet.sourceFingerprint}',
          );
        } else {
          final seed = await _newSeedRepository.createFromMnemonic(
            mnemonicWords: oldSeed.mnemonicList(),
          );
          seeds.add(seed);
          debugPrint('Imported seed: ${oldWallet.sourceFingerprint}');
        }
      }
      return seeds;
    } catch (e) {
      debugPrint('SKIP: $e');
      return [];
    }
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
          label: oldExternalWallet.name ?? oldExternalWallet.sourceFingerprint,
        );
      }
      count++;
    }
    return count;
    // TODO: Store newWallet in the new database
  }

  Future<int> _storeWatchOnlyWallet(List<OldWallet> oldWatchOnlyWallets) async {
    int count = 0;
    for (final oldWatchOnlyWallet in oldWatchOnlyWallets) {
      final network =
          oldWatchOnlyWallet.baseWalletType == OldBaseWalletType.Bitcoin
              ? (oldWatchOnlyWallet.isTestnet()
                  ? Network.bitcoinTestnet
                  : Network.bitcoinMainnet)
              : (oldWatchOnlyWallet.isTestnet()
                  ? Network.liquidTestnet
                  : Network.liquidMainnet);

      final scriptType = switch (oldWatchOnlyWallet.scriptType) {
        OldScriptType.bip84 => ScriptType.bip84,
        OldScriptType.bip49 => ScriptType.bip49,
        OldScriptType.bip44 => ScriptType.bip44,
      };

      final source = switch (oldWatchOnlyWallet.type) {
        OldBBWalletType.main => WalletSource.mnemonic,
        OldBBWalletType.coldcard => WalletSource.coldcard,
        OldBBWalletType.xpub => WalletSource.xpub,
        OldBBWalletType.words => WalletSource.mnemonic,
        OldBBWalletType.descriptors => WalletSource.descriptors,
      };
      final xpubFromDescriptor = fullKeyFromDescriptor(
        oldWatchOnlyWallet.internalPublicDescriptor,
      );
      if (source == WalletSource.coldcard || source == WalletSource.xpub) {
        await _newWalletRepository.importWatchOnlyWallet(
          xpub: xpubFromDescriptor,
          scriptType: scriptType,
          network: network,
          label:
              oldWatchOnlyWallet.name ?? oldWatchOnlyWallet.sourceFingerprint,
        );
      }
      count++;
    }
    return count;
  }
}

String fullKeyFromDescriptor(String descriptor) {
  final descriptorStripped = removeChecksumFromDesc(descriptor);
  final startIndex = descriptorStripped.indexOf('(');
  final cut1 = descriptorStripped.substring(startIndex + 1);
  final endIndex = cut1.indexOf(')');
  return cut1.substring(
    0,
    endIndex - 4,
  ); // eg externalDesc: wpkh([fingerprint/hdpath]xpub/0/*); hence -4 from )
}

String removeChecksumFromDesc(String descriptor) {
  final endIndex = descriptor.indexOf('#');
  if (endIndex == -1) return descriptor;
  return descriptor.substring(0, endIndex);
}
