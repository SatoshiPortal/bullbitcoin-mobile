import 'dart:async';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/datasource/new_wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_wallet_metadata_service.dart';

class NewWalletRepository {
  final NewWalletMetadataDatasource _walletMetadataDatasource;

  NewWalletRepository({
    required NewWalletMetadataDatasource walletMetadataDatasource,
  }) : _walletMetadataDatasource = walletMetadataDatasource;

  Future<void> createWalletMetadata({
    required NewSeedEntity seed,
    required NewNetwork network,
    required NewScriptType scriptType,
    String label = '',
    bool isDefault = false,
  }) async {
    // Derive and store the wallet metadata
    final walletLabel =
        isDefault &&
                (network == NewNetwork.bitcoinMainnet ||
                    network == NewNetwork.bitcoinTestnet)
            ? 'Secure Bitcoin'
            : isDefault &&
                (network == NewNetwork.liquidMainnet ||
                    network == NewNetwork.liquidTestnet)
            ? 'Instant Payments'
            : label;
    final metadata = await NewWalletMetadataService.deriveFromSeed(
      seed: seed,
      network: network,
      scriptType: scriptType,
      label: walletLabel,
      isDefault: isDefault,
    );
    await _walletMetadataDatasource.store(metadata);
  }

  Future<void> importWatchOnlyWalletMetadata({
    required String xpub,
    required NewNetwork network,
    required NewScriptType scriptType,
    required String label,
  }) async {
    final metadata = await NewWalletMetadataService.deriveFromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );

    await _walletMetadataDatasource.store(metadata);
  }
}

class NewWalletNotFoundException implements Exception {
  final String message;

  const NewWalletNotFoundException(this.message);
}
