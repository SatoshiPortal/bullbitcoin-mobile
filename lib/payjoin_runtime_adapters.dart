import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
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
  final WalletRepository _wallets;
  final WalletTransactionRepository _transactions;

  const AppPayjoinTransactionAdapter(this._wallets, this._transactions);

  @override
  Stream<void> watchWallet(String walletId) => _wallets.walletSyncFinishedStream
      .where((wallet) => wallet.id == walletId);

  @override
  Future<bool> isTransactionVisible({
    required String walletId,
    required String transactionId,
    bool refresh = false,
  }) async {
    return await _transactions.getWalletTransaction(
          transactionId,
          walletId: walletId,
          sync: refresh,
        ) !=
        null;
  }

  @override
  Future<void> refreshWallet(String walletId) async {
    await _wallets.getWallet(walletId, sync: true);
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
    // Lifecycle info events are periodic recovery/polling noise. Keep warnings
    // and severe lifecycle events, plus all session-specific info events.
    if (event.code == PayjoinLogCode.lifecycle &&
        (event.level == PayjoinLogLevel.debug ||
            event.level == PayjoinLogLevel.info)) {
      return;
    }
    final message =
        'Payjoin ${event.code.name}'
        '${event.sessionRef == null ? '' : ' ${event.sessionRef}'}';
    switch (event.level) {
      case PayjoinLogLevel.debug || PayjoinLogLevel.info:
        log.info(message);
      case PayjoinLogLevel.warning:
        log.warning(message);
      case PayjoinLogLevel.severe:
        // The engine's own error when it gave us one: Sentry groups on it, so
        // substituting a synthetic error would file every failure of a given
        // code under one signature and hide the cause.
        log.severe(
          message: message,
          error: event.error ?? StateError('Payjoin engine ${event.code.name}'),
          trace: event.trace ?? StackTrace.current,
        );
    }
  }
}
