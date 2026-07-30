import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
    final message =
        'Payjoin ${event.code.name}'
        '${event.sessionRef == null ? '' : ' ${event.sessionRef}'}';
    switch (event.level) {
      case PayjoinLogLevel.debug || PayjoinLogLevel.info:
        log.info(message);
      case PayjoinLogLevel.warning:
        log.warning(message);
      case PayjoinLogLevel.severe:
        log.severe(
          message: message,
          error: StateError('Payjoin engine ${event.code.name}'),
          trace: event.trace ?? StackTrace.current,
        );
    }
  }
}
