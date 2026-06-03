import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class BtcpayWalletConstants {
  const BtcpayWalletConstants._();

  static const bip85Alias = 'BTCPay';
  static const bitcoinSpecId = 'btcpay-bitcoin';
  static const liquidSpecId = 'btcpay-liquid';
  static const bitcoinLabel = 'BTCPay Bitcoin';
  static const liquidLabel = 'BTCPay Liquid';
}

enum BtcpayWalletNetwork {
  bitcoin,
  liquid;

  bool get isBitcoin => this == BtcpayWalletNetwork.bitcoin;
  bool get isLiquid => this == BtcpayWalletNetwork.liquid;

  Network networkForEnvironment(Environment environment) {
    return switch ((this, environment)) {
      (BtcpayWalletNetwork.bitcoin, Environment.mainnet) =>
        Network.bitcoinMainnet,
      (BtcpayWalletNetwork.bitcoin, Environment.testnet) =>
        Network.bitcoinTestnet,
      (BtcpayWalletNetwork.liquid, Environment.mainnet) =>
        Network.liquidMainnet,
      (BtcpayWalletNetwork.liquid, Environment.testnet) =>
        Network.liquidTestnet,
    };
  }

  String get walletLabel {
    return switch (this) {
      BtcpayWalletNetwork.bitcoin => BtcpayWalletConstants.bitcoinLabel,
      BtcpayWalletNetwork.liquid => BtcpayWalletConstants.liquidLabel,
    };
  }

  String get specId {
    return switch (this) {
      BtcpayWalletNetwork.bitcoin => BtcpayWalletConstants.bitcoinSpecId,
      BtcpayWalletNetwork.liquid => BtcpayWalletConstants.liquidSpecId,
    };
  }

  static BtcpayWalletNetwork? tryFromSpecId(String specId) {
    return switch (specId) {
      BtcpayWalletConstants.bitcoinSpecId => BtcpayWalletNetwork.bitcoin,
      BtcpayWalletConstants.liquidSpecId => BtcpayWalletNetwork.liquid,
      _ => null,
    };
  }
}
