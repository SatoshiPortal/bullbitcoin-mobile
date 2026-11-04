import 'package:wallet/wallet.dart';

class WalletCoinMapper {
  static WalletCoin toEntity(
    WalletUtxoModel model, {
    required String walletId,
    bool isFrozen = false,
  }) {
    switch (model) {
      case BitcoinWalletUtxoModel _:
        return WalletCoin.bitcoin(
          walletId: walletId,
          txId: model.txId,
          vout: model.vout,
          amountSat: model.amountSat,
          scriptPubkey: model.scriptPubkey,
          address: model.address,
          addressKeyChain: model.isExternalKeyChain
              ? WalletAddressKeyChain.external
              : WalletAddressKeyChain.internal,
          isFrozen: isFrozen,
          confirmations: model.confirmations,
        );
      case LiquidWalletUtxoModel _:
        return WalletCoin.liquid(
          walletId: walletId,
          txId: model.txId,
          vout: model.vout,
          amountSat: model.amountSat,
          scriptPubkey: model.scriptPubkey,
          standardAddress: model.standardAddress,
          confidentialAddress: model.confidentialAddress,
          isFrozen: isFrozen,
          confirmations: model.confirmations,
        );
    }
  }
}
