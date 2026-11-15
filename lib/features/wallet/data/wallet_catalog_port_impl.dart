import 'wallet_metadata_service.dart';

import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// Reads the existing Drift catalog. Never opens native stores or secrets.
final class WalletCatalogPortImpl implements WalletCatalogPort {
  final WalletMetadataDatasource _metadata;
  int _invalidCount = 0;

  WalletCatalogPortImpl(this._metadata);

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async {
    try {
      final descriptors = <PublicWalletDescriptor>[];
      var invalid = 0;
      for (final row in await _metadata.fetchAll()) {
        switch (descriptorFromMetadata(row)) {
          case Ok(:final value):
            descriptors.add(value);
          case Err():
            invalid++;
        }
      }
      if (invalid != _invalidCount) {
        _invalidCount = invalid;
        log.warning('Wallet catalog validation invalid_count=$invalid');
      }
      return Ok(List.unmodifiable(descriptors));
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    try {
      final row = await _metadata.fetch(key.id);
      if (row == null) return const Err(SyncNotFoundFailure());
      final result = descriptorFromMetadata(row);
      if (result case Ok(:final value) when value.key != key) {
        return const Err(SyncNotFoundFailure());
      }
      return result;
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  static Result<PublicWalletDescriptor, SyncFailure> descriptorFromMetadata(
    WalletMetadataModel row,
  ) {
    final Network network;
    try {
      network = row.network.shared;
      final hasSuffix = row.id.endsWith(WalletMetadataService.regtestSuffix);
      if (hasSuffix != (network.env == NetworkEnv.regtest)) {
        return const Err(SyncInvalidCatalogFailure());
      }
    } on FormatException {
      return const Err(SyncInvalidCatalogFailure());
    }
    final key = WalletKey(id: row.id, network: network);
    switch (network) {
      case BitcoinNetwork():
        final parsed = const BitcoinPolicyCodec().parseDescriptor(
          descriptor: row.publicDescriptor,
          network: network,
        );
        if (parsed case Ok(:final value)) {
          return Ok(
            BitcoinWalletDescriptor(
              key: key,
              scriptType: value.scriptType,
              origin: WalletMetadataService.originFromId(row.id),
              externalDescriptor: value.externalDescriptor,
              internalDescriptor: value.internalDescriptor,
            ),
          );
        }
        return const Err(SyncInvalidCatalogFailure());
      case LiquidNetwork():
        final script = row.inferredScriptType;
        if (script == null ||
            !LiquidWalletDescriptor.isConfidentialDescriptor(
              row.publicDescriptor,
            )) {
          return const Err(SyncInvalidCatalogFailure());
        }
        return Ok(
          LiquidWalletDescriptor(
            key: key,
            scriptType: script.shared,
            origin: WalletMetadataService.originFromId(row.id),
            combinedCtDescriptor: row.publicDescriptor,
          ),
        );
    }
  }
}
