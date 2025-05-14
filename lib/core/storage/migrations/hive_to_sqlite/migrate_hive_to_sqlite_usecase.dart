import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/entities/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/tables/new_wallet_metadata_table.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/old_wallet_repository.dart';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bip32/bip32.dart';
import 'package:flutter/foundation.dart';

class MigrateHiveToSqliteUsecase {
  final SqliteDatabase _sqliteDatabase;
  final NewSeedRepository _newSeedRepository;
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;

  MigrateHiveToSqliteUsecase({
    required SqliteDatabase sqliteDatabase,
    required NewSeedRepository newSeedRepository,
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
  }) : _sqliteDatabase = sqliteDatabase,
       _newSeedRepository = newSeedRepository,
       _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository;

  Future<bool> execute() async {
    try {
      final settings = await _sqliteDatabase.managers.settings.get();
      if (settings.isNotEmpty) {
        debugPrint('skipping migration: sqlite settings already exists');
        return false;
      }

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
      final seedsImported = await _storeNewSeeds(oldFingerprints);
      debugPrint('migration: $seedsImported/${oldFingerprints.length} seeds');

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
        continue;
      }
    }
    return seeds;
  }

  // ignore: unused_element
  Future<void> _storeMainWallets(
    List<OldWallet> oldMainWallets,
    NewSeedEntity mainWalletSeed,
  ) async {
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

      final origin = newEncodeOrigin(
        fingerprint: oldWallet.sourceFingerprint,
        network: network,
        scriptType: scriptType,
      );
      final label = switch (network) {
        NewNetwork.bitcoinMainnet => 'Secure Bitcoin',
        NewNetwork.bitcoinTestnet => 'Secure Bitcoin Test',
        NewNetwork.liquidMainnet => 'Instant Paymnets',
        NewNetwork.liquidTestnet => 'Instant Payments Test',
      };

      final root = BIP32.fromSeed(mainWalletSeed.bytes);
      final derivationPath = "m/${scriptType.purpose}'/${network.coinType}'/0'";
      final derivedAccountKey = root.derivePath(derivationPath);
      final xpub = derivedAccountKey.neutered();
      final xpubString = xpub.convert(scriptType.getXpubType(network));
      final xpubFingerprint = xpub.fingerprintHex;

      // ignore: unused_local_variable
      final newWallet = NewWallet(
        origin: origin,
        label: label,
        network: network,
        isDefault: oldWallet.mainWallet,
        masterFingerprint: oldWallet.mnemonicFingerprint,
        xpubFingerprint: xpubFingerprint,
        scriptType: scriptType,
        xpub: xpubString,
        externalPublicDescriptor: oldWallet.externalPublicDescriptor,
        internalPublicDescriptor: oldWallet.internalPublicDescriptor,
        source: NewWalletSource.mnemonic,
        balanceSat: BigInt.from(oldWallet.balance ?? 0),
        isPhysicalBackupTested: oldWallet.backupTested,
        latestPhysicalBackup: oldWallet.lastBackupTested,
      );

      // TODO: Store newWallet in the new database
    }
  }

  // ignore: unused_element
  Future<void> _storeExternalWallets(
    List<OldWallet> oldExternalWallets,
  ) async {}
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
