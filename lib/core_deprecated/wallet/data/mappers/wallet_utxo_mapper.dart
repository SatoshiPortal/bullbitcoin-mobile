import 'package:bb_mobile/core_deprecated/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_utxo.dart';

class WalletUtxoMapper {
  static WalletUtxo toEntity(
    WalletUtxoModel model, {
    required String walletId,
    List<String> labels = const [],
    List<String> addressLabels = const [],
    bool isFrozen = false,
  }) {
    switch (model) {
      case BitcoinWalletUtxoModel _:
        return WalletUtxo.bitcoin(
          walletId: walletId,
          txId: model.txId,
          vout: model.vout,
          amountSat: model.amountSat,
          scriptPubkey: model.scriptPubkey,
          address: model.address,
          addressKeyChain: model.isExternalKeyChain
              ? WalletAddressKeyChain.external
              : WalletAddressKeyChain.internal,
          labels: labels,
          addressLabels: addressLabels,
          isFrozen: isFrozen,
        );
      case LiquidWalletUtxoModel _:
        return WalletUtxo.liquid(
          walletId: walletId,
          txId: model.txId,
          vout: model.vout,
          amountSat: model.amountSat,
          scriptPubkey: model.scriptPubkey,
          standardAddress: model.standardAddress,
          confidentialAddress: model.confidentialAddress,
          labels: labels,
          addressLabels: addressLabels,
          isFrozen: isFrozen,
        );
    }
  }

  static WalletUtxoModel fromEntity(WalletUtxo entity) {
    switch (entity) {
      case BitcoinWalletUtxo _:
        return WalletUtxoModel.bitcoin(
          txId: entity.txId,
          vout: entity.vout,
          amountSat: entity.amountSat,
          scriptPubkey: entity.scriptPubkey,
          address: entity.address,
          isExternalKeyChain:
              entity.addressKeyChain == WalletAddressKeyChain.external,
        );
      case LiquidWalletUtxo _:
        return WalletUtxoModel.liquid(
          txId: entity.txId,
          vout: entity.vout,
          amountSat: entity.amountSat,
          scriptPubkey: entity.scriptPubkey,
          standardAddress: entity.standardAddress,
          confidentialAddress: entity.confidentialAddress,
        );
    }
  }
}
