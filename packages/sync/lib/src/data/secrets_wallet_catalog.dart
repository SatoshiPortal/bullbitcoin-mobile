import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SecretFailure;
import 'package:secrets/storage.dart';

import '../domain/ports/wallet_catalog_port.dart';
import '../domain/public_wallet_descriptor.dart';
import '../domain/sync_failure.dart';
import '../domain/wallet_key.dart';

/// Maps the authorized Secrets projection at Sync's existing catalog port.
final class SecretsWalletCatalog implements WalletCatalogPort {
  final Future<Result<List<RegisteredWalletDescriptor>, SecretFailure>>
  Function()
  _read;

  int _invalidCount = 0;

  SecretsWalletCatalog._(this._read);

  factory SecretsWalletCatalog.foreground(SecretsInventory inventory) =>
      SecretsWalletCatalog._(inventory.listDescriptors);

  /// Removes the catalog entry of a deletion the native writer finishes
  /// after an interruption.
  static Future<Result<void, SyncFailure>> Function(WalletKey) removal(
    SecretsInventory inventory,
  ) => (key) async => (await inventory.removeWallet(
    key.id,
  )).mapErr((_) => const SyncStorageFailure());

  factory SecretsWalletCatalog.background(
    BackgroundWalletDescriptors catalog,
  ) => SecretsWalletCatalog._(catalog.list);

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async {
    switch (await _read()) {
      case Err():
        return const Err(SyncStorageFailure());
      case Ok(:final value):
        final descriptors = <PublicWalletDescriptor>[];
        var invalid = 0;
        for (final row in value) {
          final descriptor = _descriptor(row);
          if (descriptor == null) {
            invalid++;
          } else {
            descriptors.add(descriptor);
          }
        }
        if (invalid != _invalidCount) {
          _invalidCount = invalid;
          log.warning('Wallet catalog validation invalid_count=$invalid');
        }
        return Ok(List.unmodifiable(descriptors));
    }
  }

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    switch (await _read()) {
      case Err():
        return const Err(SyncStorageFailure());
      case Ok(:final value):
        for (final row in value) {
          if (row.id != key.id) continue;
          final descriptor = _descriptor(row);
          if (descriptor == null) return const Err(SyncInvalidCatalogFailure());
          return descriptor.key == key
              ? Ok(descriptor)
              : const Err(SyncNotFoundFailure());
        }
        return const Err(SyncNotFoundFailure());
    }
  }

  static final _originPattern = RegExp(
    r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]',
  );

  static PublicWalletDescriptor? _descriptor(RegisteredWalletDescriptor row) {
    final Network? network = switch (row.network) {
      'bitcoinMainnet' => BitcoinNetwork.mainnet,
      'bitcoinTestnet' => BitcoinNetwork.testnet,
      'bitcoinRegtest' => BitcoinNetwork.regtest,
      'liquidMainnet' => LiquidNetwork.mainnet,
      'liquidTestnet' => LiquidNetwork.testnet,
      'liquidRegtest' => LiquidNetwork.regtest,
      _ => null,
    };
    if (network == null) return null;

    const suffix = ':regtest';
    final hasSuffix = row.id.endsWith(suffix);
    if (hasSuffix != (network.env == NetworkEnv.regtest)) return null;
    final origin = hasSuffix
        ? row.id.substring(0, row.id.length - suffix.length)
        : row.id;
    if (origin.startsWith('el') != (network is LiquidNetwork)) return null;
    final script = switch (_originPattern.firstMatch(origin)?.group(2)) {
      '84h' => ScriptType.bip84,
      '49h' => ScriptType.bip49,
      '44h' => ScriptType.bip44,
      _ => null,
    };
    if (script == null) return null;

    final key = WalletKey(id: row.id, network: network);
    final external = row.externalDescriptor;
    final internal = row.internalDescriptor;
    return switch (network) {
      BitcoinNetwork()
          when BitcoinWalletDescriptor.isPublicDescriptor(external) &&
              BitcoinWalletDescriptor.isPublicDescriptor(internal) =>
        BitcoinWalletDescriptor(
          key: key,
          scriptType: script,
          origin: origin,
          externalDescriptor: external,
          internalDescriptor: internal,
        ),
      LiquidNetwork()
          when LiquidWalletDescriptor.isConfidentialDescriptor(external) =>
        LiquidWalletDescriptor(
          key: key,
          scriptType: script,
          origin: origin,
          combinedCtDescriptor: external,
        ),
      _ => null,
    };
  }
}
