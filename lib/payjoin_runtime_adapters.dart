import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

final class AppPayjoinBlockchainAdapter implements PayjoinBlockchainPort {
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _servers;

  const AppPayjoinBlockchainAdapter(this._blockchain, this._servers);

  @override
  Future<void> broadcastTransaction({
    required BitcoinNetwork network,
    required Uint8List transaction,
  }) => _servers.runWithFallback<void>(
    network: ElectrumServerNetwork.fromEnvironment(
      isTestnet: !network.isMainnet,
      isLiquid: false,
    ),
    operation: (connection) =>
        _blockchain.broadcastTransaction(transaction, connection: connection),
  );

  @override
  Future<void> broadcastPsbt({
    required BitcoinNetwork network,
    required String psbt,
  }) => _servers.runWithFallback<void>(
    network: ElectrumServerNetwork.fromEnvironment(
      isTestnet: !network.isMainnet,
      isLiquid: false,
    ),
    operation: (connection) =>
        _blockchain.broadcastPsbt(psbt, connection: connection),
  );
}

final class AppPayjoinFeesAdapter implements PayjoinFeesPort {
  final FeesRepository _fees;

  const AppPayjoinFeesAdapter(this._fees);

  @override
  Future<FeeRate> fastestFeeRate({required BitcoinNetwork network}) async {
    final fees = await _fees.getNetworkFees(
      network: Network.fromEnvironment(
        isTestnet: !network.isMainnet,
        isLiquid: false,
      ),
    );
    return FeeRate(fees.fastest.value.toDouble());
  }
}

final class AppPayjoinTransactionAdapter implements PayjoinTransactionPort {
  static const _reconcileAttempts = 3;

  final WalletRepository _wallets;
  final WalletTransactionRepository _transactions;
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _servers;
  // Pacing between two wallet syncs of [_reconcileWallet]; tests shorten it.
  final Duration reconcileDelay;

  const AppPayjoinTransactionAdapter(
    this._wallets,
    this._transactions,
    this._blockchain,
    this._servers, {
    this.reconcileDelay = const Duration(seconds: 5),
  });

  @override
  Stream<void> watchWallet(String walletId) => _wallets.walletSyncFinishedStream
      .where((wallet) => wallet.id == walletId);

  /// A refreshed lookup asks the Electrum server about this one transaction
  /// instead of syncing the whole wallet, which takes 15 to 120 seconds
  /// over Tor and delayed every payjoin outcome by as much.
  ///
  /// The wallet's own copy only answers a non-refreshed lookup: a pending
  /// transaction the wallet saw earlier can since have been evicted or
  /// replaced, and the engine settles sessions on this answer.
  @override
  Future<bool> isTransactionVisible({
    required String walletId,
    required String transactionId,
    bool refresh = false,
  }) async {
    if (!refresh) {
      return await _transactions.getWalletTransaction(
            transactionId,
            walletId: walletId,
          ) !=
          null;
    }

    final wallet = (await _wallets.getWallet(walletId)).fold(
      (wallet) => wallet,
      (failure) =>
          throw Exception('Payjoin wallet unavailable: ${failure.runtimeType}'),
    );
    final bool isKnownRemotely;
    try {
      isKnownRemotely = await _servers.runWithFallback<bool>(
        network: ElectrumServerNetwork.fromEnvironment(
          isTestnet: wallet.isTestnet,
          isLiquid: false,
        ),
        operation: (connection) => _blockchain.isTransactionKnown(
          transactionId,
          connection: connection,
        ),
        // Another server would word its reply the same way; surface it.
        isTransient: (e) =>
            e is Exception && e is! UnrecognizedElectrumReplyException,
      );
    } on UnrecognizedElectrumReplyException {
      // A server we cannot classify (Electrum Personal Server, bitcoind
      // without txindex): take the slow road of a script-based wallet sync
      // and read the wallet copy, instead of failing every lookup. A sync
      // can join a pass that started before the broadcast, so an absence is
      // only trusted after a second pass.
      for (var pass = 1; pass <= 2; pass++) {
        final transaction = await _transactions.getWalletTransaction(
          transactionId,
          walletId: walletId,
          sync: true,
        );
        if (transaction != null) return true;
      }
      return false;
    }
    if (isKnownRemotely) {
      // Let the wallet catch up so balances and history show the transaction
      // the payjoin session is about to report.
      unawaited(_reconcileWallet(walletId, transactionId));
    }
    return isKnownRemotely;
  }

  /// Syncs until the wallet holds [transactionId], a few times at most: one
  /// sync can fail, or join a pass that started before the transaction was
  /// broadcast and so miss it. The session outcome never waits on this.
  Future<void> _reconcileWallet(String walletId, String transactionId) async {
    for (var attempt = 1; attempt <= _reconcileAttempts; attempt++) {
      if (attempt > 1) await Future<void>.delayed(reconcileDelay * attempt);
      try {
        await refreshWallet(walletId);
        final transaction = await _transactions.getWalletTransaction(
          transactionId,
          walletId: walletId,
        );
        if (transaction != null) return;
      } catch (e) {
        // Nobody awaits this: a throw here would be an unhandled error.
        log.warning('Payjoin wallet refresh failed: ${e.runtimeType}');
      }
    }
    log.warning('Payjoin wallet did not catch up with a settled transaction');
  }

  @override
  Future<void> refreshWallet(String walletId) async {
    // Refresh only: the caller wants the side-effecting sync, not the wallet.
    (await _wallets.getWallet(walletId, sync: true)).fold(
      (_) {},
      (failure) => throw Exception(
        'Payjoin wallet refresh failed: ${failure.runtimeType}',
      ),
    );
  }
}

final class AppPayjoinLabelsAdapter implements PayjoinLabelsPort {
  final LabelsFacade _labels;

  const AppPayjoinLabelsAdapter(this._labels);

  @override
  Future<void> labelTransaction({
    required String walletId,
    required String transactionId,
  }) async {
    await _labels.store(
      NewLabel.tx(
        transactionId: transactionId,
        label: LabelSystem.payjoin.label,
        origin: walletId,
      ),
    );
  }
}

final class AppPayjoinLogAdapter implements PayjoinLogPort {
  const AppPayjoinLogAdapter();

  @override
  void write(PayjoinLogEvent event) {
    final message = _describe(event);
    switch (event.level) {
      case PayjoinLogLevel.debug:
        // Per-poll and per-relay chatter: debug output only, never the
        // exported file, which a few minutes of polling would flood.
        log.info(message);
      case PayjoinLogLevel.info when event.code == PayjoinLogCode.lifecycle:
        log.info(message);
      case PayjoinLogLevel.info:
        // A session milestone: the exported file must keep it, or a shared
        // log cannot tell how far an attempt went before it fell back.
        log.fine(message);
      case PayjoinLogLevel.warning:
        log.warning(message);
      case PayjoinLogLevel.severe:
        // Sentry must not receive arbitrary exception text either. Group by
        // structured code and cause type, retaining the original stack.
        log.severe(
          message: message,
          error: Exception(
            'Payjoin ${event.code.name}'
            '${event.error == null ? '' : ' ${event.error.runtimeType}'}',
          ),
          trace: event.trace ?? StackTrace.current,
        );
    }
  }

  /// Reads on its own in an exported log: who, what, which session, and the
  /// cause reduced to its type. Foreign exception text can contain
  /// transaction IDs, payment URIs or custom server URLs, so it never appears.
  static String _describe(PayjoinLogEvent event) {
    final role = event.role;
    final sessionRef = event.sessionRef;
    final error = event.error;
    return [
      'Payjoin',
      ?role?.name,
      '${event.code.name}: ${event.code.description}',
      if (sessionRef != null) 'ref=$sessionRef',
      if (error != null) 'cause=${_describeCause(error)}',
    ].join(' ');
  }

  /// A transport failure says whether the directory or relay could not be
  /// reached, timed out or answered with an error status; its message is
  /// dropped because it quotes the URL.
  static String _describeCause(Object error) => switch (error) {
    DioException(:final type, :final response) =>
      'DioException.${type.name}'
          '${response == null ? '' : '(${response.statusCode})'}',
    _ => '${error.runtimeType}',
  };
}
