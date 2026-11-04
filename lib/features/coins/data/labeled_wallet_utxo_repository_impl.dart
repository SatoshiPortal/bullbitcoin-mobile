import 'package:wallet/wallet.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/features/labels/labels_facade.dart';
import '../domain/labeled_wallet_utxo_repository.dart';
import '../domain/wallet_utxo.dart';
import 'wallet_utxo_mapper.dart';

class LabeledWalletUtxoRepositoryImpl implements LabeledWalletUtxoRepository {
  final WalletUtxoRepository _wallet;
  final LabelsFacade _labelsFacade;

  LabeledWalletUtxoRepositoryImpl({
    required this._wallet,
    required this._labelsFacade,
  });

  @override
  Future<List<WalletUtxo>> getWalletUtxos({required String walletId}) async {
    final coins = await _wallet.getWalletUtxos(walletId: walletId);
    return Future.wait(
      coins.map((coin) async {
        final labelModels = await _labelsFacade.fetchByReference(
          '${coin.txId}:${coin.vout}',
        );
        final txLabels = await _labelsFacade.fetchByReference(coin.txId);
        List<Label> addressLabels;
        switch (coin) {
          case LiquidWalletCoin():
            final (standardAddressLabels, confidentialAddressLabels) = await (
              _labelsFacade.fetchByReference(coin.standardAddress),
              _labelsFacade.fetchByReference(coin.confidentialAddress),
            ).wait;
            addressLabels = [
              ...standardAddressLabels,
              ...confidentialAddressLabels,
            ];
          case BitcoinWalletCoin():
            addressLabels = await _labelsFacade.fetchByReference(coin.address);
        }
        return WalletUtxoMapper.toEntity(
          coin,
          labels: labelModels,
          txLabels: txLabels,
          addressLabels: addressLabels,
        );
      }).toList(),
    );
  }

  @override
  Future<void> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _wallet.freezeUtxos(walletId: walletId, outpoints: outpoints);

  @override
  Future<void> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _wallet.unfreezeUtxos(walletId: walletId, outpoints: outpoints);

  @override
  Future<List<Outpoint>> getAllFrozenOutpoints() =>
      _wallet.getAllFrozenOutpoints();
}
