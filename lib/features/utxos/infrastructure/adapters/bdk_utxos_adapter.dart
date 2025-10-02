import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/utxos/domain/ports/utxos_port.dart';
import 'package:bb_mobile/features/utxos/domain/utxo.dart';
import 'package:bb_mobile/features/utxos/infrastructure/factories/bdk_wallet_factory.dart';

class BdkUtxosAdapter implements UtxosPort {
  final BdkWalletFactory _bdkWalletFactory;

  const BdkUtxosAdapter({required BdkWalletFactory bdkWalletFactory})
    : _bdkWalletFactory = bdkWalletFactory;

  @override
  Future<Utxo?> getUtxoFromWallet({
    required String txId,
    required int index,
    required Wallet wallet,
  }) async {
    if (!wallet.network.isBitcoin) {
      throw ArgumentError(
        'BdkUtxosAdapter can only be used with Bitcoin wallets',
      );
    }

    try {
      final bdkWallet = await _bdkWalletFactory.createWallet(wallet);
      final unspentList = bdkWallet.listUnspent();

      final matchingUnspent = unspentList.firstWhere(
        (unspent) =>
            unspent.outpoint.txid == txId && unspent.outpoint.vout == index,
        orElse: () => throw Exception('UTXO not found'),
      );

      final address =
          await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
            matchingUnspent.txout.scriptPubkey.bytes,
            isTestnet: wallet.network.isTestnet,
          );

      return Utxo(
        txId: matchingUnspent.outpoint.txid,
        index: matchingUnspent.outpoint.vout,
        address: address ?? '',
        valueSat: matchingUnspent.txout.value.toInt(),
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
    if (!wallet.network.isBitcoin) {
      throw ArgumentError(
        'BdkUtxosAdapter can only be used with Bitcoin wallets',
      );
    }

    final bdkWallet = await _bdkWalletFactory.createWallet(wallet);
    final unspentList = bdkWallet.listUnspent();

    final utxos = <Utxo>[];
    for (final unspent in unspentList) {
      final address =
          await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
            unspent.txout.scriptPubkey.bytes,
            isTestnet: wallet.network.isTestnet,
          );

      utxos.add(
        Utxo(
          txId: unspent.outpoint.txid,
          index: unspent.outpoint.vout,
          address: address ?? '',
          valueSat: unspent.txout.value.toInt(),
        ),
      );
    }

    final startIndex = offset ?? 0;
    final endIndex = limit != null ? startIndex + limit : utxos.length;
    final actualEndIndex = endIndex > utxos.length ? utxos.length : endIndex;

    return utxos.sublist(startIndex, actualEndIndex);
  }
}
