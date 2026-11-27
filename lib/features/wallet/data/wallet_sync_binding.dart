import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// Adapts application wallet values to Sync at the remaining legacy call sites.
abstract final class WalletSyncBinding {
  /// Resolve application metadata before invoking a native capability.
  static WalletKey keyFromMetadata(WalletMetadataModel row) =>
      value(descriptorFromMetadata(row)).key;

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
        // Liquid uses only the external descriptor.
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
