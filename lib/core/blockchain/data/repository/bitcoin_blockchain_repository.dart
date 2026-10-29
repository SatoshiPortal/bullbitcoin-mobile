import 'package:bb_mobile/core/wallet/data/cbf_privacy_guard.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

/// Thin repository over [BdkBitcoinBlockchainDatasource]. Its only job is to
/// route broadcast operations through [ElectrumServersPort.runWithFallback]
/// so callers cannot fetch a server list themselves — the privacy / fallback
/// rule lives in one place.
class BitcoinBlockchainRepository {
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _serversPort;
  final WalletMetadataDatasource? metadata;
  final BitcoinSyncRouting? bitcoinSyncRouting;
  final WalletSourceOperationCoordinator? coordinator;

  const BitcoinBlockchainRepository({
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required this._serversPort,
    this.metadata,
    this.bitcoinSyncRouting,
    this.coordinator,
  }) : _blockchain = blockchainDatasource;

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required bool isTestnet,
    String? walletId,
  }) {
    return _route(
      walletId,
      () => _blockchain.extractFinalizedPsbt(finalizedPsbt),
      () => _serversPort.runWithFallback<String>(
        network: ElectrumServerNetwork.fromEnvironment(
          isTestnet: isTestnet,
          isLiquid: false,
        ),
        operation: (connection) =>
            _blockchain.broadcastPsbt(finalizedPsbt, connection: connection),
      ),
    );
  }

  Future<String> broadcastTransaction(
    List<int> transaction, {
    required bool isTestnet,
    String? walletId,
  }) {
    return _route(
      walletId,
      () => Uint8List.fromList(transaction),
      () => _serversPort.runWithFallback<String>(
        network: ElectrumServerNetwork.fromEnvironment(
          isTestnet: isTestnet,
          isLiquid: false,
        ),
        operation: (connection) => _blockchain.broadcastTransaction(
          Uint8List.fromList(transaction),
          connection: connection,
        ),
      ),
    );
  }

  Future<String> _route(
    String? walletId,
    Uint8List Function() bytes,
    Future<String> Function() electrum,
  ) async {
    final store = metadata;
    final lock = coordinator;
    if (store == null || lock == null) {
      return electrum(); // Test-only legacy composition.
    }
    if (walletId == null) {
      // No attributable wallet: hold all existing Bitcoin policies through I/O.
      return CbfPrivacyGuard(store, lock).runUnattributedElectrum(electrum);
    }
    final initial = await store.fetch(walletId);
    if (initial == null || !initial.isBitcoin) {
      throw const BitcoinSyncOperationException(DeletedWalletFailure());
    }
    Future<String> Function()? relay;
    final result = await lock.runExclusive<String?>(
      WalletSourceKey(
        walletId,
        'bitcoin',
        initial.isTestnet ? 'testnet' : 'mainnet',
      ),
      (session) async {
        final current = await store.fetch(walletId);
        if (current == null) {
          throw const BitcoinSyncOperationException(DeletedWalletFailure());
        }
        if (current.bitcoinSyncSource ==
            BitcoinSyncSource.compactBlockFilters) {
          final routing = bitcoinSyncRouting;
          if (routing == null) {
            throw const BitcoinSyncOperationException(
              CbfRemoteLookupForbiddenFailure(),
            );
          }
          final Uint8List transaction;
          try {
            transaction = bytes();
          } on Exception {
            throw const BitcoinSyncOperationException(
              CbfBroadcastNotRelayedFailure(),
            );
          }
          relay = () => routing.broadcast(current, null, transaction);
          return null;
        }
        return electrum();
      },
      timeout: null,
    );
    if (result != null) return result;
    final cbfRelay = relay;
    if (cbfRelay == null) throw StateError('Missing broadcast route');
    return cbfRelay();
  }
}
