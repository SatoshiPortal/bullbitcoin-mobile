import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/utxos/domain/ports/utxos_port.dart';
import 'package:bb_mobile/features/utxos/domain/utxo.dart';
import 'package:bb_mobile/features/utxos/infrastructure/factories/lwk_wallet_factory.dart';

class LwkUtxosAdapter implements UtxosPort {
  final LwkWalletFactory _lwkWalletFactory;

  const LwkUtxosAdapter({required LwkWalletFactory lwkWalletFactory})
    : _lwkWalletFactory = lwkWalletFactory;

  @override
  Future<Utxo?> getUtxoFromWallet({
    required String txId,
    required int index,
    required Wallet wallet,
  }) async {
    if (!wallet.network.isLiquid) {
      throw ArgumentError(
        'LwkUtxosAdapter can only be used with Liquid wallets',
      );
    }

    try {
      final lwkWallet = await _lwkWalletFactory.createWallet(wallet);
      final utxos = await lwkWallet.utxos();

      final matchingUtxo = utxos.firstWhere(
        (utxo) => utxo.outpoint.txid == txId && utxo.outpoint.vout == index,
        orElse: () => throw Exception('UTXO not found'),
      );

      // For Liquid, we'll use the confidential address if available, otherwise the standard address
      final address =
          matchingUtxo.address.confidential.isNotEmpty
              ? matchingUtxo.address.confidential
              : matchingUtxo.address.standard;

      return Utxo(
        txId: matchingUtxo.outpoint.txid,
        index: matchingUtxo.outpoint.vout,
        address: address,
        valueSat: matchingUtxo.unblinded.value.toInt(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Utxo>> getUtxosFromWallet(
    Wallet wallet, {
    int? limit,
    int? offset,
  }) async {
    if (!wallet.network.isLiquid) {
      throw ArgumentError(
        'LwkUtxosAdapter can only be used with Liquid wallets',
      );
    }

    final lwkWallet = await _lwkWalletFactory.createWallet(wallet);
    final lwkUtxos = await lwkWallet.utxos();

    final utxos =
        lwkUtxos.map((utxo) {
          // For Liquid, we'll use the confidential address if available, otherwise the standard address
          final address =
              utxo.address.confidential.isNotEmpty
                  ? utxo.address.confidential
                  : utxo.address.standard;

          return Utxo(
            txId: utxo.outpoint.txid,
            index: utxo.outpoint.vout,
            address: address,
            valueSat: utxo.unblinded.value.toInt(),
          );
        }).toList();

    final startIndex = offset ?? 0;
    final endIndex = limit != null ? startIndex + limit : utxos.length;
    final actualEndIndex = endIndex > utxos.length ? utxos.length : endIndex;

    return utxos.sublist(startIndex, actualEndIndex);
  }
}
