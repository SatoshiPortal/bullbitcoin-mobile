import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
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

  /// Resolve application metadata before invoking a native capability.
  static WalletKey keyFromMetadata(WalletMetadataModel row) =>
      value(descriptorFromMetadata(row)).key;

  static Future<WalletKey> keyForId(
    WalletMetadataDatasource metadata,
    String id,
  ) async {
    try {
      final row = await metadata.fetch(id);
      if (row == null) {
        throw const WalletSnapshotException(SyncNotFoundFailure());
      }
      return WalletKey(id: row.id, network: row.network.shared);
    } on WalletSnapshotException {
      rethrow;
    } on Exception {
      throw const WalletSnapshotException(SyncStorageFailure());
    }
  }

  /// The legacy app repositories retain throwing boundaries until migrated.
  static T value<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  static Result<PublicWalletDescriptor, SyncFailure> descriptorFromMetadata(
    WalletMetadataModel row,
  ) {
    // Legacy origin decoding throws strings. Contain only that legacy boundary;
    // programmer Errors from the datasource or this mapper must still surface.
    final Network network;
    final ScriptType script;
    try {
      final origin = WalletMetadataService.parseOrigin(origin: row.origin);
      network = row.network.shared;
      script = origin.script.shared;
      if (row.origin.startsWith('el') != (network is LiquidNetwork)) {
        return const Err(SyncInvalidCatalogFailure());
      }
      final hasSuffix = row.id.endsWith(WalletMetadataService.regtestSuffix);
      if (hasSuffix != (network.env == NetworkEnv.regtest)) {
        return const Err(SyncInvalidCatalogFailure());
      }
    } on String {
      return const Err(SyncInvalidCatalogFailure());
    } on FormatException {
      return const Err(SyncInvalidCatalogFailure());
    }
    final external = row.externalPublicDescriptor;
    final internal = row.internalPublicDescriptor;
    final key = WalletKey(id: row.id, network: network);
    switch (network) {
      case BitcoinNetwork():
        if (!BitcoinWalletDescriptor.isPublicDescriptor(external) ||
            !BitcoinWalletDescriptor.isPublicDescriptor(internal)) {
          return const Err(SyncInvalidCatalogFailure());
        }
        return Ok(
          BitcoinWalletDescriptor(
            key: key,
            scriptType: script,
            origin: row.origin,
            externalDescriptor: external,
            internalDescriptor: internal,
          ),
        );
      case LiquidNetwork():
        // Liquid uses only the external descriptor, as WalletModel.fromMetadata does.
        if (!LiquidWalletDescriptor.isConfidentialDescriptor(external)) {
          return const Err(SyncInvalidCatalogFailure());
        }
        return Ok(
          LiquidWalletDescriptor(
            key: key,
            scriptType: script,
            origin: row.origin,
            combinedCtDescriptor: external,
          ),
        );
    }
  }
}
