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
  final SecretsInventory? _inventory;
  final SessionToken? _token;
  final BackgroundWalletDescriptors? _background;
  int _invalidCount = 0;

  SecretsWalletCatalog._foreground(SecretsInventory inventory, [this._token])
    : _inventory = inventory,
      _background = null;

  SecretsWalletCatalog._background(BackgroundWalletDescriptors background)
    : _inventory = null,
      _token = null,
      _background = background;

  factory SecretsWalletCatalog.foreground(SecretsInventory inventory) =>
      SecretsWalletCatalog._foreground(inventory);

  /// The read-only session of an unbound foreground catalog.
  ForegroundSession? get foregroundSession =>
      _token == null ? _inventory?.foregroundSession : null;

  /// Binds catalog reads to [token], without following any later grant.
  WalletCatalogPort? captureForeground(SessionToken token) {
    final inventory = _inventory;
    if (inventory == null ||
        (_token != null && !identical(_token, token)) ||
        !inventory.foregroundSession.isCurrent(token)) {
      return null;
    }
    return SecretsWalletCatalog._foreground(inventory, token);
  }

  /// Removes the catalog entry of a deletion the native writer finishes
  /// after an interruption.
  static Future<Result<void, SyncFailure>> Function(WalletKey) removal(
    SecretsInventory inventory,
  ) =>
      (key) async =>
          (await inventory.removeWallet(key.id))
              .mapErr((_) => const SyncStorageFailure());

  factory SecretsWalletCatalog.background(
    BackgroundWalletDescriptors catalog,
  ) => SecretsWalletCatalog._background(catalog);

  Future<Result<T, SyncFailure>> _readCatalog<T>(
    Result<T, SyncFailure> Function(List<RegisteredWalletDescriptor>) project,
  ) async {
    final inventory = _inventory;
    final Result<List<RegisteredWalletDescriptor>, SecretFailure> rows;
    if (inventory != null) {
      final session = inventory.foregroundSession;
      final token = _token ?? session.capture();
      if (token == null || !session.isCurrent(token)) {
        return const Err(SyncClosedFailure());
      }
      rows = await inventory.listDescriptorsFor(token);
      if (!session.isCurrent(token)) return const Err(SyncClosedFailure());
    } else if (_background case final background?) {
      rows = await background.list();
    } else {
      return const Err(SyncClosedFailure());
    }
    return switch (rows) {
      Err() => const Err(SyncStorageFailure()),
      Ok(:final value) => project(value),
    };
  }

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() =>
      _readCatalog((rows) {
        final descriptors = <PublicWalletDescriptor>[];
        var invalid = 0;
        for (final row in rows) {
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
      });

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(WalletKey key) =>
      _readCatalog((rows) {
        for (final row in rows) {
          if (row.id != key.id) continue;
          final descriptor = _descriptor(row);
          if (descriptor == null) return const Err(SyncInvalidCatalogFailure());
          return descriptor.key == key
              ? Ok(descriptor)
              : const Err(SyncNotFoundFailure());
        }
        return const Err(SyncNotFoundFailure());
      });

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
