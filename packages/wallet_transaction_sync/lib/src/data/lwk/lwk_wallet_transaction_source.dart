import 'dart:io';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../domain/entities/wallet_transaction_observation.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/wallet_source_sync_observation.dart';
import '../../domain/entities/wallet_source_observation.dart';
import '../../domain/ports/wallet_transaction_source_port.dart';
import '../../domain/wallet_network_key.dart';
import '../../domain/wallet_source_configuration.dart';
import '../../domain/wallet_source_registration.dart';
import '../../domain/wallet_transaction_sync_failure.dart';
import '../../wallet_source_session.dart';
import 'lwk_wallet_transaction_mapper.dart';

final class LwkWalletTransactionSource implements WalletTransactionSourcePort {
  final Map<WalletNetworkKey, LwkElectrumConfiguration> _configurations = {};

  @override
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  refreshLocal(
    WalletSourceRegistration registration,
    WalletSourceSession session,
  ) async {
    session.ensureOpen();
    final configuration = _configuration(registration);
    _configurations[registration.key] = configuration;
    final root = Directory(configuration.databaseRootPath);
    if (!await root.exists()) {
      return const Err(WalletSourceStateMissingFailure());
    }
    try {
      final wallet = await _open(configuration);
      try {
        return Ok(
          await _observation(
            wallet,
            registration,
            networkOperation: false,
            discover: false,
          ),
        );
      } finally {
        wallet.dispose();
      }
    } catch (error) {
      final incompatible = lwkStateIncompatibleFailure(error);
      if (incompatible != null) return Err(incompatible);
      return const Err(SourceFailure(SourceFailureReason.unknown));
    }
  }

  @override
  Future<Result<WalletSourceSyncObservation, WalletTransactionSyncFailure>>
  synchronize(
    WalletSourceRegistration registration,
    WalletSourceSession session, {
    required bool discover,
  }) async {
    session.ensureOpen();
    final configuration = _configuration(registration);
    _configurations[registration.key] = configuration;
    try {
      await Directory(configuration.databaseRootPath).create(recursive: true);
      final wallet = await _open(configuration);
      try {
        final baselineTxids = (await _transactions(
          wallet,
          configuration,
        )).map((transaction) => transaction.txid).toSet();
        var synced = false;
        for (final url in configuration.electrumUrls) {
          try {
            // LWK exposes one scan mode. Discovery deliberately requests that
            // same capability rather than inventing a second SDK operation.
            await wallet.sync_(
              electrumUrl: url,
              validateDomain: configuration.validateDomain,
              stopAtIndex: configuration.stopAtIndex,
              timeout: configuration.timeout,
            );
            synced = true;
            break;
          } catch (error) {
            final incompatible = lwkStateIncompatibleFailure(error);
            if (incompatible != null) return Err(incompatible);
            // Connection-level failure: try the next configured endpoint.
          }
        }
        if (!synced) {
          return const Err(SourceFailure(SourceFailureReason.unavailable));
        }
        return Ok(
          WalletSourceSyncObservation(
            observation: await _observation(
              wallet,
              registration,
              networkOperation: true,
              discover: discover,
            ),
            baselineTxids: baselineTxids,
          ),
        );
      } finally {
        wallet.dispose();
      }
    } catch (error) {
      final incompatible = lwkStateIncompatibleFailure(error);
      if (incompatible != null) return Err(incompatible);
      return const Err(
        ExtractionFailure(safeMessage: 'LWK wallet operation failed'),
      );
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
    final configuration = provided is LwkElectrumConfiguration
        ? provided
        : _configurations[key];
    if (configuration == null) {
      return const Err(WalletSourceStateMissingFailure());
    }
    try {
      final root = Directory(configuration.databaseRootPath);
      if (await root.exists()) await root.delete(recursive: true);
      return const Ok(null);
    } catch (_) {
      return const Err(DeletionFailure());
    }
  }

  LwkElectrumConfiguration _configuration(
    WalletSourceRegistration registration,
  ) {
    final configuration = registration.configuration;
    if (configuration is! LwkElectrumConfiguration) {
      throw StateError('LWK source requires LwkElectrumConfiguration');
    }
    return configuration;
  }

  Future<lwk.Wallet> _open(LwkElectrumConfiguration configuration) =>
      lwk.Wallet.init(
        network: configuration.isTestnet
            ? lwk.LiquidNetwork.testnet
            : lwk.LiquidNetwork.mainnet,
        dbpath: configuration.databaseRootPath,
        descriptor: lwk.Descriptor(
          ctDescriptor: configuration.confidentialPublicDescriptor,
        ),
      );

  Future<WalletSourceObservation> _observation(
    lwk.Wallet wallet,
    WalletSourceRegistration registration, {
    required bool networkOperation,
    required bool discover,
  }) async {
    final configuration = _configuration(registration);
    final asset = configuration.isTestnet
        ? lwk.getLtestAssetId()
        : lwk.getLbtcAssetId();
    final projections = await wallet.transactionsProjection(
      includeUnblindingData: false,
    );
    return WalletSourceObservation(
      key: registration.key,
      registration: registration,
      transactions: [
        for (final projection in projections)
          mapLwkTransaction(projection, lbtcAssetId: asset),
      ],
      capabilities: {'electrum', if (discover) 'scan'},
      evidenceLevel: networkOperation
          ? WalletEvidenceLevel.walletSourceReported
          : WalletEvidenceLevel.localSourceState,
      sourceTip: null,
    );
  }

  Future<List<WalletTransaction>> _transactions(
    lwk.Wallet wallet,
    LwkElectrumConfiguration configuration,
  ) async {
    final asset = configuration.isTestnet
        ? lwk.getLtestAssetId()
        : lwk.getLbtcAssetId();
    final projections = await wallet.transactionsProjection(
      includeUnblindingData: false,
    );
    return [
      for (final projection in projections)
        mapLwkTransaction(projection, lbtcAssetId: asset),
    ];
  }
}

@visibleForTesting
WalletTransactionSyncFailure? lwkStateIncompatibleFailure(Object error) {
  if (error case lwk.LwkError(
    :final msg,
  ) when msg.contains('UpdateOnDifferentStatus')) {
    return const WalletSourceStateIncompatibleFailure();
  }
  return null;
}
