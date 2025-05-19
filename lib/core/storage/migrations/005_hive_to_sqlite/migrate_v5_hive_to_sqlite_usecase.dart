import 'dart:convert';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_swap.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:boltz/boltz.dart' as boltz;
import 'package:flutter/foundation.dart';

class MigrateToV5HiveToSqliteToUsecase {
  final SeedRepository _newSeedRepository;
  final WalletRepository _newWalletRepository;
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;
  final MigrationSecureStorageDatasource _secureStorage;
  // ignore: unused_field
  final SwapRepository _mainnetSwapRepository;
  MigrateToV5HiveToSqliteToUsecase({
    required SeedRepository newSeedRepository,
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
    required WalletRepository newWalletRepository,
    required MigrationSecureStorageDatasource secureStorage,
    required SwapRepository mainnetSwapRepository,
  }) : _newSeedRepository = newSeedRepository,
       _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository,
       _newWalletRepository = newWalletRepository,
       _secureStorage = secureStorage,
       _mainnetSwapRepository = mainnetSwapRepository;
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
      final mainWalletWithSwaps = await _storeMainWallets(
        oldMainnetDefaultWallets,
      );
      final externalWalletsWithSwaps = await _storeExternalWallet(
        oldMainnetExternalSignerWallets,
      );

      final finalWatchOnlyCount = await _storeWatchOnlyWallet(
        oldMainnetWatchOnlyWallets,
      );
      debugPrint(
        'wallet migration completed: ${seedsImported.length} seeds, ${mainWalletWithSwaps.length}/${oldMainnetDefaultWallets.length} default wallets\n${externalWalletsWithSwaps.length}/${oldMainnetExternalSignerWallets.length} external wallets\n$finalWatchOnlyCount/${oldMainnetWatchOnlyWallets.length} watch only wallets;\nSuccessfully migrated ${mainWalletWithSwaps.length + externalWalletsWithSwaps.length + finalWatchOnlyCount} wallets',
      );
      final allWalletsWithSwaps = [
        ...mainWalletWithSwaps,
        ...externalWalletsWithSwaps,
      ];
      final allWalletIdMappings = [
        ...mainWalletWithSwaps.map((e) => e.walletId),
        ...externalWalletsWithSwaps.map((e) => e.walletId),
      ];
      final totalSwapsLength = allWalletsWithSwaps.fold(
        0,
        (sum, wallet) => sum + wallet.oldOngoingSwaps!.length,
      );
      if (totalSwapsLength == 0) {
        debugPrint('swap migration completed: No swaps to migrate');
        return true;
      }
      final recoveredSwaps = await _recoverOldOngoingSwaps(
        allWalletsWithSwaps,
        allWalletIdMappings,
      );
      // debug print the number of swaps receoverd receoverSwaps/(total swaps = [mainWalletWithSwaps + externalWalletsWithSwaps].map through all the ongoingSwaps list and get their length summed)
      debugPrint(
        'swap migration completed: recoveredSwaps: $recoveredSwaps/$totalSwapsLength',
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

  Future<List<WalletWithOngoingSwaps>> _storeMainWallets(
    List<OldWallet> oldMainWallets,
  ) async {
    try {
      final List<WalletWithOngoingSwaps> recovered = [];
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

        final newWallet = await _newWalletRepository.createWallet(
          seed: mainWalletSeed,
          scriptType: scriptType,
          network: network,
          isDefault: true,
        );
        final ongoingSwaps = await _getOldOngoingSwaps(oldWallet);
        final walletWithSwaps = WalletWithOngoingSwaps(
          walletId: WalletIdMapping(
            oldWalletId: oldWallet.id,
            newWalletId: newWallet.id,
          ),
          oldOngoingSwaps: ongoingSwaps.toList(),
        );
        recovered.add(walletWithSwaps);
        // TODO: Store newWallet in the new database
      }
      return recovered;
    } catch (e) {
      debugPrint('migration failed: $e');
      return [];
    }
  }

  // TODO: Handle passphrase wallets
  Future<List<WalletWithOngoingSwaps>> _storeExternalWallet(
    List<OldWallet> oldExternalWallets,
  ) async {
    final List<WalletWithOngoingSwaps> recovered = [];
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
        final newWallet = await _newWalletRepository.createWallet(
          seed: newExternalSeed,
          scriptType: scriptType,
          network: network,
          label: oldExternalWallet.name ?? oldExternalWallet.sourceFingerprint,
        );
        final ongoingSwaps = await _getOldOngoingSwaps(oldExternalWallet);
        final walletWithSwaps = WalletWithOngoingSwaps(
          walletId: WalletIdMapping(
            oldWalletId: oldExternalWallet.id,
            newWalletId: newWallet.id,
          ),
          oldOngoingSwaps: ongoingSwaps.toList(),
        );
        recovered.add(walletWithSwaps);
      }
    }
    return recovered;
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
        try {
          await _newWalletRepository.importWatchOnlyWallet(
            xpub: xpubFromDescriptor,
            scriptType: scriptType,
            network: network,
            label:
                oldWatchOnlyWallet.name ?? oldWatchOnlyWallet.sourceFingerprint,
          );
          count++;
        } catch (e) {
          debugPrint('Failed to create watch only wallet: $e');
          continue;
        }
      }
    }
    return count;
  }

  Future<List<OldSwapTx>> _getOldOngoingSwaps(OldWallet oldWallet) async {
    final List<OldSwapTx> ongoingSwaps = [];
    final swaps = oldWallet.swaps;
    if (swaps.isNotEmpty) {
      for (final swap in swaps) {
        final isOngoing =
            !swap.settledSubmarine() ||
            !swap.settledReverse() ||
            !swap.settledOnchain() ||
            !swap.refundedAny() ||
            !swap.expiredOnchain() ||
            !swap.expiredReverse() ||
            !swap.expiredSubmarine() ||
            !swap.failed();
        if (isOngoing) {
          ongoingSwaps.add(swap);
        }
      }
    }
    return ongoingSwaps;
  }

  Future<int> _recoverOldOngoingSwaps(
    List<WalletWithOngoingSwaps> walletWithOngoingSwaps,
    List<WalletIdMapping> allWalletIdMappings,
  ) async {
    int count = 0;
    for (final item in walletWithOngoingSwaps) {
      // final newWalletId = item.walletId;
      for (final swap in item.oldOngoingSwaps!) {
        final swapSensitive = await _secureStorage.fetch(
          key: '${OldStorageKeys.swapTxSensitive.name}_${swap.id}',
        );

        if (swap.isLiquid() && swap.isLnSwap()) {
          final swapSensitiveConcrete = OldLnSwapTxSensitive.fromJson(
            jsonDecode(swapSensitive!) as Map<String, dynamic>,
          );
          final sdkSwapClass = swap.toLbtcLnSwap(swapSensitiveConcrete);
          final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
          final jsonSwap = await sdkSwapClass.toJson();
          await _secureStorage.store(key: key, value: jsonSwap);
          final receiveAddress = swap.claimAddress;
          await _mainnetSwapRepository.migrateOldSwap(
            primaryWalletId: item.walletId.newWalletId,
            swapId: swap.id,
            swapType:
                swap.isReverse()
                    ? SwapType.lightningToLiquid
                    : SwapType.liquidToLightning,
            lockupTxid: swap.lockupTxid,
            counterWalletId: null,
            isCounterWalletExternal: null,
            claimAddress: receiveAddress,
          );
          count++;
        }
        if (swap.isBitcoin() && swap.isLnSwap()) {
          final swapSensitiveConcrete = OldLnSwapTxSensitive.fromJson(
            jsonDecode(swapSensitive!) as Map<String, dynamic>,
          );
          final sdkSwapClass = swap.toBtcLnSwap(swapSensitiveConcrete);
          final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
          final jsonSwap = await sdkSwapClass.toJson();
          await _secureStorage.store(key: key, value: jsonSwap);
          final receiveAddress = swap.claimAddress;
          await _mainnetSwapRepository.migrateOldSwap(
            primaryWalletId: item.walletId.newWalletId,
            swapId: swap.id,
            swapType:
                swap.isReverse()
                    ? SwapType.lightningToBitcoin
                    : SwapType.bitcoinToLightning,
            lockupTxid: swap.lockupTxid,
            counterWalletId: null,
            isCounterWalletExternal: null,
            claimAddress: receiveAddress,
          );
          count++;
        }
        if (swap.isChainSwap()) {
          final toWalletIdOld = swap.chainSwapDetails?.toWalletId ?? '';

          final counterWalletIdMapping = allWalletIdMappings.firstWhere(
            (e) => e.oldWalletId == toWalletIdOld,
            orElse:
                () => WalletIdMapping(
                  oldWalletId: toWalletIdOld,
                  newWalletId: toWalletIdOld,
                  oldWalletIdIsExternal: true,
                ), // this is likely an address (swap to external)
          );

          final swapSensitiveConcrete = OldChainSwapTxSensitive.fromJson(
            jsonDecode(swapSensitive!) as Map<String, dynamic>,
          );
          final sdkSwapClass = swap.toChainSwap(swapSensitiveConcrete);
          final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
          final jsonSwap = await sdkSwapClass.toJson();
          await _secureStorage.store(key: key, value: jsonSwap);
          await _mainnetSwapRepository.migrateOldSwap(
            primaryWalletId: item.walletId.newWalletId,
            swapId: swap.id,
            swapType:
                swap.chainSwapDetails?.direction ==
                        boltz.ChainSwapDirection.lbtcToBtc
                    ? SwapType.liquidToBitcoin
                    : SwapType.bitcoinToLiquid,
            lockupTxid: swap.lockupTxid,
            counterWalletId: counterWalletIdMapping.newWalletId,
            isCounterWalletExternal:
                counterWalletIdMapping.oldWalletIdIsExternal,
            claimAddress: null,
          );

          count++;
        }
      }
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

class WalletWithOngoingSwaps {
  final WalletIdMapping walletId;
  final List<OldSwapTx>? oldOngoingSwaps;

  WalletWithOngoingSwaps({
    required this.walletId,
    required this.oldOngoingSwaps,
  });
}

class WalletIdMapping {
  final String oldWalletId;
  final String newWalletId;
  final bool oldWalletIdIsExternal;
  WalletIdMapping({
    required this.oldWalletId,
    required this.newWalletId,
    this.oldWalletIdIsExternal = false,
  });
}
