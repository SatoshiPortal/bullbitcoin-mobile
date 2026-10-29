import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:bull_tor/tor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Shell adapter: source policy is read under the caller's existing session. The package owns nodes, discovery metadata, and their complete lifetimes.
final class BitcoinSyncRouting {
  final WalletTransactionSyncFacade facade;
  final SettingsRepository settings;
  final Tor Function() tor;
  final Future<String> Function()? documentsDirectory;
  final Future<List<WalletMetadataModel>> Function()? allWallets;

  const BitcoinSyncRouting({
    required this.facade,
    required this.settings,
    required this.tor,
    this.documentsDirectory,
    this.allWallets,
  });

  Future<WalletSourceRegistration> registration(
    WalletMetadataModel metadata, {
    DateTime? deadline,
    bool verifyTor = true,
  }) async {
    if (deadline != null && !deadline.isAfter(DateTime.now().toUtc())) {
      throw const BitcoinSyncOperationException(WalletSyncDeferredFailure());
    }
    final checkpoint = _resolveCheckpoint(metadata);
    final resolved = switch (checkpoint) {
      Ok(:final value) => value,
      Err(:final failure) => throw BitcoinSyncOperationException(failure),
    };
    final appSettings = await settings.fetch();
    int? port;
    if (appSettings.useTorProxy && verifyTor) {
      try {
        final endpoint = TorProxyEndpoint(
          host: '127.0.0.1',
          port: appSettings.torProxyPort,
        );
        final verification = tor().external.verify(endpoint);
        final state = deadline == null
            ? await verification
            : await verification.timeout(
                deadline.difference(DateTime.now().toUtc()),
              );
        if (state case TorReady(:final route)) {
          port = route.endpoint.port;
        }
      } catch (_) {
        /* Fail closed via the explicit required-route flag. */
      }
    }
    final model = WalletModel.fromMetadata(metadata);
    final directory =
        await (documentsDirectory?.call() ??
            getApplicationDocumentsDirectory().then(
              (directory) => directory.path,
            ));
    return WalletSourceRegistration.withFingerprint(
      key: WalletNetworkKey(
        metadata.id,
        'bitcoin',
        metadata.isTestnet ? 'testnet' : 'mainnet',
      ),
      sourceKind:
          'bdk_electrum', // Stable persisted BDK identity across policy changes.
      configuration: BdkCbfConfiguration(
        externalPublicDescriptor: metadata.externalPublicDescriptor,
        internalPublicDescriptor: metadata.internalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        databaseFilePath: '$directory/${model.hexId}_bdk_dart',
        checkpoint: resolved,
        torRequired: appSettings.useTorProxy,
        socksPort: port,
        deadline: deadline,
      ),
    );
  }

  Future<bool> isCurrent(WalletSourceRegistration registration) async {
    final provider = allWallets;
    if (provider == null) return false;
    final current = (await provider())
        .where((wallet) => wallet.id == registration.key.walletId)
        .firstOrNull;
    if (current == null ||
        current.bitcoinSyncSource != BitcoinSyncSource.compactBlockFilters) {
      return false;
    }
    final configuration = registration.configuration as BdkCbfConfiguration;
    final saved = await settings.fetch();
    if (saved.useTorProxy != configuration.torRequired ||
        (saved.useTorProxy &&
            configuration.socksPort != null &&
            saved.torProxyPort != configuration.socksPort)) {
      return false;
    }
    final checkpoint = _resolveCheckpoint(current);
    return checkpoint
            is Ok<BitcoinSyncCheckpoint, WalletTransactionSyncFailure> &&
        checkpoint.value == configuration.checkpoint &&
        current.externalPublicDescriptor ==
            configuration.externalPublicDescriptor &&
        current.internalPublicDescriptor ==
            configuration.internalPublicDescriptor;
  }

  Result<BitcoinSyncCheckpoint, WalletTransactionSyncFailure>
  _resolveCheckpoint(WalletMetadataModel metadata) =>
      const ResolveBitcoinSyncCheckpointUsecase().execute(
        network: metadata.isTestnet
            ? BitcoinNetwork.testnet
            : BitcoinNetwork.mainnet,
        birthday: metadata.birthday,
        scriptType: BitcoinSyncScriptType.fromDescriptor(
          metadata.externalPublicDescriptor,
        ),
        now: DateTime.now().toUtc(),
      );

  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  synchronize(
    WalletMetadataModel metadata,
    WalletSourceSession? session, {
    bool discover = false,
    bool allowInitialScan = true,
    DateTime? deadline,
  }) async {
    try {
      final source = await registration(metadata, deadline: deadline);
      return discover
          ? facade.discoverWalletHistory(
              DiscoverWalletHistoryRequest(source, session: session),
            )
          : facade.synchronizeWallet(
              SynchronizeWalletRequest(
                source,
                session: session,
                allowInitialScan: allowInitialScan,
              ),
            );
    } on BitcoinSyncOperationException catch (error) {
      return Err(error.failure);
    }
  }

  Future<String> broadcast(
    WalletMetadataModel metadata,
    WalletSourceSession? session,
    Uint8List bytes,
  ) async {
    final deadline = DateTime.now().toUtc().add(const Duration(seconds: 30));
    Future<String> operation() async {
      final provisional = await registration(
        metadata,
        deadline: deadline,
        verifyTor: false,
      );
      final staged = await facade.stageCbfTransaction(
        registration: provisional,
        transactionBytes: bytes,
      );
      if (staged case Err(:final failure)) {
        throw BitcoinSyncOperationException(failure);
      }
      final verified = await registration(metadata, deadline: deadline);
      final list = allWallets;
      if (list != null) {
        final registrations = <WalletSourceRegistration>[];
        for (final wallet in await list()) {
          if (wallet.isBitcoin &&
              wallet.bitcoinSyncSource ==
                  BitcoinSyncSource.compactBlockFilters) {
            registrations.add(
              wallet.id == metadata.id
                  ? verified
                  : await registration(wallet, deadline: deadline),
            );
          }
        }
        final ready = await facade.reconcileCbfWallets(registrations);
        if (ready case Err(:final failure)) {
          throw BitcoinSyncOperationException(failure);
        }
      }
      final result = await facade.broadcastCbfTransaction(
        registration: verified,
        session: session,
        transactionBytes: bytes,
      );
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw BitcoinSyncOperationException(failure),
      };
    }

    try {
      return await operation().timeout(
        deadline.difference(DateTime.now().toUtc()),
      );
    } on TimeoutException {
      throw const BitcoinSyncOperationException(
        CbfBroadcastNotRelayedFailure(),
      );
    }
  }
}
