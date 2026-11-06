import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';

import 'wallet_catalog_port_impl.dart';

/// Owns application lifecycle orchestration; the shell only composes this owner.
/// Catalog rows and secrets survive failed provisioning so startup can resume it.
abstract interface class WalletNativeLifecycle {
  Future<void> create(WalletMetadataModel metadata);
  Future<void> delete(WalletMetadataModel metadata);
  Future<({String address, int index})> receive(
    WalletMetadataModel metadata, {
    bool advance = false,
  });
}

final class WalletNativeRuntime implements WalletNativeLifecycle {
  final WalletCatalogPort _catalog;
  final ReservedAddressPort _reserved;
  final WalletMetadataDatasource _metadata;
  final ElectrumSync _sync;
  final Future<String> Function() _documentsDirectory;
  final _changes = StreamController<WalletRevisionState>.broadcast();
  final _unavailable = <WalletKey, TransactionSyncFailure>{};
  Future<_NativeServices>? _opening;
  Future<void>? _initialization;

  WalletNativeRuntime({
    required this._catalog,
    required this._reserved,
    required this._metadata,
    required this._sync,
    required this._documentsDirectory,
  });

  Stream<WalletRevisionState> get changes => _changes.stream;

  Future<_NativeServices> get _services => _opening ??= _open();

  Future<_NativeServices> _open() async {
    final documents = await _documentsDirectory();
    final revisions = RevisionStore(writerMetadataPath(documents));
    revisions.changes.listen(_changes.add);
    final writer = NativeWalletWriter(
      lockDirectory: writerLockDirectory(documents),
      revisions: revisions,
      documentsDirectory: documents,
      catalog: _catalog,
      reservedAddresses: _reserved,
    );
    return _NativeServices(
      documents,
      revisions,
      writer,
      WalletSnapshotReader(
        documentsDirectory: documents,
        readiness: PersistedWalletReadiness(revisions),
        requiredSchemaVersion: writerSchemaVersion,
        revisions: revisions,
        liquidAdmission: writer,
      ),
    );
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final services = await _services;
    final descriptors = _value(await _catalog.list());
    for (final descriptor in descriptors) {
      final state = await _state(services, descriptor.key);
      if (state?.lifecycle == WalletLifecycle.deleted) {
        // A crash after the tombstone but before catalog removal must not resurrect.
        final result = await services.writer.delete(
          descriptor.key,
          expectedGeneration: state?.stamp.generation ?? 0,
        );
        if (result is Ok) {
          await _metadata.delete(descriptor.key.id);
        } else if (result case Err(:final failure)) {
          _unavailable[descriptor.key] = failure;
        }
        continue;
      }
      // A catalog-only row is resumable provisioning. Existing stores are always
      // adopted with load; a previously active missing store is never recreated.
      final path = nativeWalletStoragePath(services.documents, descriptor.key);
      final existing =
          FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
      var result = await services.writer.create(
        descriptor.key,
        expectedGeneration: state?.stamp.generation ?? 0,
        existingOnly: existing,
      );
      if (result case Err(failure: TransactionSyncNeedsRepairFailure())) {
        result = await services.writer.repair(
          descriptor.key,
          expectedGeneration: state?.stamp.generation ?? 0,
        );
        if (result is Ok) {
          final synced = await _sync.execute(descriptor);
          if (synced case Err(:final failure)) {
            _unavailable[descriptor.key] = failure;
          }
          await services.revisions.read(descriptor.key);
        }
      }
      if (result case Err(:final failure)) {
        _unavailable[descriptor.key] = failure;
      }
    }
    log.fine(
      'Native wallet initialization finished count=${descriptors.length} unavailable=${_unavailable.length}',
    );
  }

  Future<WalletRevisionState?> _state(
    _NativeServices services,
    WalletKey key,
  ) async => switch (await services.revisions.read(key)) {
    Ok(:final value) => value,
    Err(failure: TransactionSyncNotFoundFailure()) => null,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  @override
  Future<void> create(WalletMetadataModel metadata) async {
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final services = await _services;
    final state = await _state(services, descriptor.key);
    _value(
      await services.writer.create(
        descriptor.key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
    _unavailable.remove(descriptor.key);
  }

  @override
  Future<void> delete(WalletMetadataModel metadata) async {
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final services = await _services;
    final state = await _state(services, descriptor.key);
    _value(
      await services.writer.delete(
        descriptor.key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
    _unavailable.remove(descriptor.key);
  }

  @override
  Future<({String address, int index})> receive(
    WalletMetadataModel metadata, {
    bool advance = false,
  }) async {
    await initialize();
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final services = await _services;
    final state = await _state(services, descriptor.key);
    final issued = _value(
      await services.writer.receive(
        descriptor.key,
        expectedGeneration: state?.stamp.generation ?? 0,
        advance: advance,
      ),
    );
    return (address: issued.address, index: issued.index);
  }

  Future<bdk.Wallet> bitcoin(WalletModel model) async =>
      _borrow<bdk.Wallet>(model);
  Future<lwk.Wallet> liquid(WalletModel model) async =>
      _borrow<lwk.Wallet>(model);

  Future<T> _borrow<T extends Object>(WalletModel model) async {
    await initialize();
    final key = WalletKey(
      id: model.id,
      network: model is PublicBdkWalletModel
          ? (model.isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet)
          : (model.isTestnet ? LiquidNetwork.testnet : LiquidNetwork.mainnet),
    );
    final failure = _unavailable[key];
    if (failure != null) throw WalletSnapshotException(failure);
    return (await _services).reader.borrowedHandle<T>(key, _catalog);
  }

  /// Called after every worker outcome, including interrupted/failed writes.
  Future<void> refresh(WalletKey key) async {
    final services = await _services;
    final state = await services.revisions.read(key);
    if (state case Ok(
      value: final value,
    ) when value.lifecycle == WalletLifecycle.active) {
      _unavailable.remove(key);
    }
  }

  Future<void> refreshAll() async {
    final descriptors = _value(await _catalog.list());
    for (final descriptor in descriptors) {
      await refresh(descriptor.key);
    }
  }

  Future<void> repair(WalletKey key) async {
    final services = await _services;
    final state = await _state(services, key);
    _value(
      await services.writer.repair(
        key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      await (await opening).revisions.close();
    }
    await _changes.close();
  }

  static T _value<T>(Result<T, TransactionSyncFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw WalletSnapshotException(failure),
      };
}

final class _NativeServices {
  final String documents;
  final RevisionStore revisions;
  final NativeWalletWriter writer;
  final WalletSnapshotReader reader;
  const _NativeServices(
    this.documents,
    this.revisions,
    this.writer,
    this.reader,
  );
}
