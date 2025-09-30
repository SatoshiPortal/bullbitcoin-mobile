import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/utxos/domain/ports/utxos_port.dart';
import 'package:bb_mobile/features/utxos/domain/utxo.dart';
import 'package:bb_mobile/features/utxos/infrastructure/adapters/bdk_utxos_adapter.dart';
import 'package:bb_mobile/features/utxos/infrastructure/adapters/lwk_utxos_adapter.dart';

/// Coordinates between BDK and LWK adapters based on wallet type
/// to provide a unified implementation of UtxosPort
class UtxosAdapterCoordinator implements UtxosPort {
  final BdkUtxosAdapter _bdkUtxosAdapter;
  final LwkUtxosAdapter _lwkUtxosAdapter;

  const UtxosAdapterCoordinator({
    required BdkUtxosAdapter bdkUtxosAdapter,
    required LwkUtxosAdapter lwkUtxosAdapter,
  })  : _bdkUtxosAdapter = bdkUtxosAdapter,
        _lwkUtxosAdapter = lwkUtxosAdapter;

  UtxosPort _getAdapterForWallet(Wallet wallet) {
    if (wallet.network.isBitcoin) {
      return _bdkUtxosAdapter;
    } else if (wallet.network.isLiquid) {
      return _lwkUtxosAdapter;
    } else {
      throw ArgumentError('Unsupported wallet network: ${wallet.network}');
    }
  }

  @override
  Future<Utxo?> getUtxoFromWallet({
    required String txId,
    required int index,
    required Wallet wallet,
  }) async {
    final adapter = _getAdapterForWallet(wallet);
    return adapter.getUtxoFromWallet(
      txId: txId,
      index: index,
      wallet: wallet,
    );
  }

  @override
  Future<List<Utxo>> getUtxosFromWallet(
    Wallet wallet, {
    int? limit,
    int? offset,
  }) async {
    final adapter = _getAdapterForWallet(wallet);
    return adapter.getUtxosFromWallet(
      wallet,
      limit: limit,
      offset: offset,
    );
  }
}