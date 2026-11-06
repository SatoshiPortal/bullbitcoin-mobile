import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Reads the existing Drift catalog. Never opens native stores or secrets.
final class WalletCatalogPortImpl implements WalletCatalogPort {
  final WalletMetadataDatasource _metadata;

  WalletCatalogPortImpl(this._metadata);

  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async {
    try {
      final descriptors = <PublicWalletDescriptor>[];
      for (final row in await _metadata.fetchAll()) {
        switch (descriptorFromMetadata(row)) {
          case Ok(:final value):
            descriptors.add(value);
          case Err(:final failure):
            return Err(failure);
        }
      }
      return Ok(List.unmodifiable(descriptors));
    } on Exception {
      return const Err(TransactionSyncStorageFailure());
    }
  }

  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async {
    try {
      final row = await _metadata.fetch(key.id);
      if (row == null) return const Err(TransactionSyncNotFoundFailure());
      final result = descriptorFromMetadata(row);
      if (result case Ok(:final value) when value.key != key) {
        return const Err(TransactionSyncNotFoundFailure());
      }
      return result;
    } on Exception {
      return const Err(TransactionSyncStorageFailure());
    }
  }

  static Result<PublicWalletDescriptor, TransactionSyncFailure>
  descriptorFromMetadata(WalletMetadataModel row) {
    // Legacy origin decoding throws strings. Contain only that legacy boundary;
    // programmer Errors from the datasource or this mapper must still surface.
    final Network network;
    final ScriptType script;
    try {
      final origin = WalletMetadataService.decodeOrigin(origin: row.id);
      network = origin.network.shared;
      script = origin.script.shared;
    } on String {
      return const Err(TransactionSyncInvalidCatalogFailure());
    }
    final external = row.externalPublicDescriptor;
    final internal = row.internalPublicDescriptor;
    final key = WalletKey(id: row.id, network: network);
    switch (network) {
      case BitcoinNetwork():
        if (!BitcoinWalletDescriptor.isPublicDescriptor(external) ||
            !BitcoinWalletDescriptor.isPublicDescriptor(internal)) {
          return const Err(TransactionSyncInvalidCatalogFailure());
        }
        return Ok(
          BitcoinWalletDescriptor(
            key: key,
            scriptType: script,
            origin: row.id,
            externalDescriptor: external,
            internalDescriptor: internal,
          ),
        );
      case LiquidNetwork():
        // Liquid uses only the external descriptor, as WalletModel.fromMetadata does.
        if (!LiquidWalletDescriptor.isConfidentialDescriptor(external)) {
          return const Err(TransactionSyncInvalidCatalogFailure());
        }
        return Ok(
          LiquidWalletDescriptor(
            key: key,
            scriptType: script,
            origin: row.id,
            combinedCtDescriptor: external,
          ),
        );
    }
  }
}
