import 'package:transaction_sync/transaction_sync.dart'
    show
        WalletOperationKind,
        WalletSourceKey,
        WalletSourceOperationCoordinator,
        WalletSourceSession;
import '../domain/wallet_metadata.dart';
import '../domain/wallet.dart';
import '../domain/wallet_sync_connection_port.dart';
import '../domain/wallet_transaction_details.dart';
import 'models/wallet_model.dart';
import 'bdk/bdk_wallet_datasource.dart';
import 'lwk/lwk_wallet_datasource.dart';
import 'wallet_snapshot_reader.dart';
import 'wallet_snapshot_mapper.dart';
import 'wallet_transaction_details_mapper.dart';

/// Owns native synchronization and local history reads; labels belong to callers.
class WalletTransactionReader {
  final BdkWalletDatasource _bdkWalletTransactionDatasource;
  final LwkWalletDatasource _lwkWalletTransactionDatasource;
  final WalletSyncConnectionPort _serversPort;
  final WalletSourceOperationCoordinator _coordinator;
  final WalletSnapshotReader _snapshots;

  WalletTransactionReader({
    required this._bdkWalletTransactionDatasource,
    required this._lwkWalletTransactionDatasource,
    required this._serversPort,
    required this._coordinator,
    required this._snapshots,
  });

  Future<List<WalletTransactionDetails>> read({
    required WalletMetadata wallet,
    String? txId,
    String? toAddress,
    bool sync = false,
  }) async {
    final details = wallet.isBitcoin
        ? await _readBitcoin(
            metadata: wallet,
            txId: txId,
            toAddress: toAddress,
            sync: sync,
          )
        : await _readLiquid(
            metadata: wallet,
            txId: txId,
            toAddress: toAddress,
            sync: sync,
          );
    return details;
  }

  Future<List<WalletTransactionDetails>> _readBitcoin({
    required WalletMetadata metadata,
    String? txId,
    String? toAddress,
    required bool sync,
  }) {
    final wallet = WalletModel.fromMetadata(metadata);
    return _coordinator.runExclusive(
      _sourceKey(wallet),
      (session) async {
        if (sync) {
          await _serversPort.runWithFallback<void>(
            network: Network.fromEnvironment(
              isTestnet: wallet.isTestnet,
              isLiquid: false,
            ),
            operation: (connection) => _bdkWalletTransactionDatasource.sync(
              wallet: wallet,
              electrumServer: connection,
            ),
          );
        }
        if (txId == null) {
          return _readSnapshot(metadata, session, toAddress);
        }
        final transactions = await _bdkWalletTransactionDatasource
            .getTransactions(wallet: wallet, txId: txId, toAddress: toAddress);
        return transactions
            .map(WalletTransactionDetailsMapper.fromModel)
            .toList();
      },
      kind: sync
          ? WalletOperationKind.synchronize
          : WalletOperationKind.refresh,
      timeout: sync ? null : const Duration(seconds: 30),
    );
  }

  Future<List<WalletTransactionDetails>> _readLiquid({
    required WalletMetadata metadata,
    String? txId,
    String? toAddress,
    required bool sync,
  }) {
    final wallet = WalletModel.fromMetadata(metadata);
    return _coordinator.runExclusive(
      _sourceKey(wallet),
      (session) async {
        if (sync) {
          await _serversPort.runWithFallback<void>(
            network: Network.fromEnvironment(
              isTestnet: wallet.isTestnet,
              isLiquid: true,
            ),
            operation: (connection) => _lwkWalletTransactionDatasource.sync(
              wallet: wallet,
              electrumServer: connection,
            ),
          );
        }
        if (txId == null) {
          return _readSnapshot(metadata, session, toAddress);
        }
        final transactions = await _lwkWalletTransactionDatasource
            .getTransactions(wallet: wallet, txId: txId, toAddress: toAddress);
        return transactions
            .where((transaction) => transaction.txId == txId)
            .map(WalletTransactionDetailsMapper.fromModel)
            .toList();
      },
      kind: sync
          ? WalletOperationKind.synchronize
          : WalletOperationKind.refresh,
      timeout: sync ? null : const Duration(seconds: 30),
    );
  }

  Future<List<WalletTransactionDetails>> _readSnapshot(
    WalletMetadata metadata,
    WalletSourceSession session,
    String? toAddress,
  ) async {
    final result = await _snapshots.read(wallet: metadata, session: session);
    return result.fold(
      (snapshot) =>
          WalletSnapshotMapper.toModels(snapshot, toAddress: toAddress),
      (failure) => throw failure,
    );
  }

  WalletSourceKey _sourceKey(WalletModel wallet) => WalletSourceKey(
    wallet.id,
    wallet is PublicLwkWalletModel ? 'liquid' : 'bitcoin',
    wallet.isTestnet ? 'testnet' : 'mainnet',
  );
}
