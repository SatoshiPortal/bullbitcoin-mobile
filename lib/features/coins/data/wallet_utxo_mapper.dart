import 'package:wallet/wallet.dart';
import '../domain/wallet_utxo.dart';
import 'package:bb_mobile/features/labels/label.dart';

class WalletUtxoMapper {
  static WalletUtxo toEntity(
    WalletCoin model, {
    List<Label> labels = const [],
    List<Label> txLabels = const [],
    List<Label> addressLabels = const [],
  }) {
    switch (model) {
      case BitcoinWalletCoin _:
        return WalletUtxo.bitcoin(
          walletId: model.walletId,
          txId: model.txId,
          vout: model.vout,
          amountSat: model.amountSat,
          scriptPubkey: model.scriptPubkey,
          address: model.address,
          addressKeyChain: model.addressKeyChain,
          labels: labels,
          txLabels: txLabels,
          addressLabels: addressLabels,
          isFrozen: model.isFrozen,
          confirmations: model.confirmations,
        );
      case LiquidWalletCoin _:
        return WalletUtxo.liquid(
          walletId: model.walletId,
          txId: model.txId,
          vout: model.vout,
          amountSat: model.amountSat,
          scriptPubkey: model.scriptPubkey,
          standardAddress: model.standardAddress,
          confidentialAddress: model.confidentialAddress,
          labels: labels,
          txLabels: txLabels,
          addressLabels: addressLabels,
          isFrozen: model.isFrozen,
          confirmations: model.confirmations,
        );
    }
  }
}
