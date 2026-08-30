import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../domain/ports/wallet_transaction_source_port.dart';
import '../../domain/wallet_source_configuration.dart';
import '../../domain/wallet_network_key.dart';
import '../../domain/wallet_source_registration.dart';
import '../../domain/wallet_transaction_sync_failure.dart';
import '../../wallet_source_session.dart';
import 'bdk_wallet_transaction_mapper.dart';

final class BdkWalletTransactionSource implements WalletTransactionSourcePort {
  final Map<WalletNetworkKey, BdkElectrumConfiguration> _configurations = {};

  @override
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  refreshLocal(
    WalletSourceRegistration registration,
    WalletSourceSession session,
  ) async {
    session.ensureOpen();
    final configuration = _configuration(registration);
    _configurations[registration.key] = configuration;
    final file = File(configuration.databaseFilePath);
    if (!await file.exists()) {
      return const Err(WalletSourceStateMissingFailure());
    }
    try {
      final open = await _open(
        registration,
        configuration,
        file,
        create: false,
      );
      try {
        return Ok(
          mapBdkObservation(
            open.wallet,
            registration: registration,
            networkOperation: false,
            discover: false,
          ),
        );
      } finally {
        open.dispose();
      }
    } catch (error) {
      return Err(_loadFailure(file, error));
    }
  }

  @override
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  synchronize(
    WalletSourceRegistration registration,
    WalletSourceSession session, {
    required bool discover,
  }) async {
    session.ensureOpen();
    final configuration = _configuration(registration);
    _configurations[registration.key] = configuration;
    final file = File(configuration.databaseFilePath);
    await file.parent.create(recursive: true);
    try {
      final open = await _open(registration, configuration, file, create: true);
      final wallet = open.wallet;
      try {
        // Connection phase: only connection/server errors may fall through
        // to the next URL. Nothing has been applied to the wallet yet.
        bdk.Update? update;
        for (final url in configuration.electrumUrls) {
          bdk.ElectrumClient? client;
          try {
            // The constructor itself opens the connection; it must sit
            // inside the per-URL try so a refused server falls through to
            // the next one instead of aborting the whole operation.
            client = bdk.ElectrumClient(
              url: url,
              socks5: null,
              timeout: null,
              retry: null,
              validateDomain: configuration.validateDomain,
            );
            update = discover
                ? client.fullScan(
                    request: wallet.startFullScan().build(),
                    stopGap: configuration.stopGap,
                    batchSize: configuration.stopGap.clamp(50, 1000),
                    fetchPrevTxouts: true,
                  )
                : client.sync_(
                    request: wallet.startSyncWithRevealedSpks().build(),
                    batchSize: configuration.stopGap.clamp(50, 1000),
                    fetchPrevTxouts: true,
                  );
            break;
          } catch (_) {
            // Connection-level failure: try the next configured server.
          } finally {
            client?.dispose();
          }
        }
        if (update == null) {
          return const Err(SourceFailure(SourceFailureReason.unavailable));
        }

        // Fatal phase: apply/persist/mapping errors must surface, never be
        // retried against another server or reported as unavailability.
        try {
          wallet.applyUpdate(update: update);
          // `Wallet.persist` returns whether staged changes were written
          // (false simply means nothing was staged); persistence FAILURES
          // throw and are mapped below.
          wallet.persist(persister: open.persister);
          return Ok(
            mapBdkObservation(
              wallet,
              registration: registration,
              networkOperation: true,
              discover: discover,
            ),
          );
        } catch (_) {
          return const Err(
            ExtractionFailure(
              safeMessage: 'applying or persisting the source update failed',
            ),
          );
        }
      } finally {
        open.dispose();
      }
    } catch (error) {
      return Err(_loadFailure(file, error));
    }
  }

  @override
  Future<Result<void, WalletTransactionSyncFailure>> delete(
    WalletNetworkKey key,
    WalletSourceSession session, {
    WalletSourceRegistration? registration,
  }) async {
    session.ensureOpen();
    final provided = registration?.configuration;
    final configuration = provided is BdkElectrumConfiguration
        ? provided
        : _configurations[key];
    if (configuration == null) {
      return const Err(WalletSourceStateMissingFailure());
    }
    final file = File(configuration.databaseFilePath);
    if (!await file.exists()) return const Ok(null);
    try {
      await file.delete();
      return const Ok(null);
    } catch (_) {
      return const Err(DeletionFailure());
    }
  }

  BdkElectrumConfiguration _configuration(
    WalletSourceRegistration registration,
  ) {
    final configuration = registration.configuration;
    if (configuration is! BdkElectrumConfiguration) {
      throw StateError('BDK source requires BdkElectrumConfiguration');
    }
    return configuration;
  }

  Future<_OpenWallet> _open(
    WalletSourceRegistration registration,
    BdkElectrumConfiguration configuration,
    File file, {
    required bool create,
  }) async {
    final existed = await file.exists();
    // The persister must outlive the wallet: the uniffi Wallet object keeps
    // using it, so both handles are owned and released together.
    final persister = bdk.Persister.newSqlite(path: file.path);
    try {
      final external = bdk.Descriptor(
        descriptor: configuration.externalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      final internal = bdk.Descriptor(
        descriptor: configuration.internalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      final wallet = (!create || existed)
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: persister,
              lookahead: configuration.stopGap,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: configuration.isTestnet
                  ? bdk.Network.testnet
                  : bdk.Network.bitcoin,
              persister: persister,
              lookahead: configuration.stopGap,
            );
      return _OpenWallet(wallet, persister);
    } catch (_) {
      persister.dispose();
      rethrow;
    }
  }

  WalletTransactionSyncFailure _loadFailure(File file, Object error) =>
      file.existsSync()
      ? const SourceFailure(SourceFailureReason.unknown)
      : const WalletSourceStateMissingFailure();
}

final class _OpenWallet {
  final bdk.Wallet wallet;
  final bdk.Persister persister;

  _OpenWallet(this.wallet, this.persister);

  void dispose() {
    try {
      wallet.dispose();
    } finally {
      persister.dispose();
    }
  }
}
