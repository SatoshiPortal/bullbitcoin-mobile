// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'state.freezed.dart';
part 'state.g.dart';

@freezed
class NetworkState with _$NetworkState {
  const factory NetworkState({
    @Default(false) bool testnet,
    // @JsonKey(
    //   includeFromJson: false,
    //   includeToJson: false,
    // )
    // bdk.Blockchain? blockchain,
    @Default(20) int reloadWalletTimer,
    @Default([]) List<ElectrumNetwork> networks,
    @Default(ElectrumTypes.bullbitcoin) ElectrumTypes selectedNetwork,
    @Default([]) List<LiquidElectrumNetwork> liquidNetworks,
    @Default(LiquidElectrumTypes.blockstream) LiquidElectrumTypes selectedLiquidNetwork,
    @Default(false) bool loadingNetworks,
    @Default('') String errLoadingNetworks,
    @Default(false) bool networkConnected,
    @Default(false) bool networkErrorOpened,

    // @Default(20) int stopGap,
    ElectrumTypes? tempNetwork,
    ElectrumNetwork? tempNetworkDetails,
    LiquidElectrumTypes? tempLiquidNetwork,
    LiquidElectrumNetwork? tempLiquidNetworkDetails,
  }) = _NetworkState;
  const NetworkState._();

  factory NetworkState.fromJson(Map<String, dynamic> json) => _$NetworkStateFromJson(json);

  ElectrumNetwork? getNetwork() {
    if (networks.isEmpty) return null;
    return networks.firstWhere((_) => _.type == selectedNetwork);
  }

  LiquidElectrumNetwork? getLiquidNetwork() {
    if (liquidNetworks.isEmpty) return null;
    return liquidNetworks.firstWhere((_) => _.type == selectedLiquidNetwork);
  }

  ElectrumNetwork? getTempOrSelectedNetwork() {
    if (networks.isEmpty) return null;
    // return tempNetwork ?? selectedNetwork;
    if (tempNetwork == null) return getNetwork();
    final n = networks;
    final t = tempNetwork;

    return n.firstWhere((_) => _.type == t);
  }

  LiquidElectrumNetwork? getTempOrSelectedLiquidNetwork() {
    if (liquidNetworks.isEmpty) return null;
    // return tempNetwork ?? selectedNetwork;
    if (tempLiquidNetwork == null) return getLiquidNetwork();
    final n = liquidNetworks;
    final t = tempLiquidNetwork;

    return n.firstWhere((_) => _.type == t);
  }

  String getNetworkUrl() {
    final network = getNetwork();
    if (network == null) return '';
    return network.getNetworkUrl(testnet, split: false);
  }

  String getLiquidNetworkUrl() {
    final network = getLiquidNetwork();
    if (network == null) return '';
    return network.getNetworkUrl(testnet, split: false);
  }

  bdk.Network getBdkNetwork() {
    if (testnet) return bdk.Network.testnet;
    return bdk.Network.bitcoin;
  }

  BBNetwork getBBNetwork() {
    if (testnet) return BBNetwork.Testnet;
    return BBNetwork.Mainnet;
  }

  // boltz.Chain getBoltzChain() {
  // if (testnet) return boltz.Chain.Testnet;
  // return boltz.Chain.Bitcoin;
  // }

  String explorerTxUrl(String txid, {bool isLiquid = false}) {
    if (isLiquid) {
      return testnet ? '$liquidMempoolTestnet/tx/$txid' : '$liquidMempool/tx/$txid';
    } else {
      return testnet ? 'https://$mempoolapi/testnet/tx/$txid' : 'https://$mempoolapi/tx/$txid';
    }
  }

  String explorerAddressUrl(String address, {bool isLiquid = false}) {
    if (isLiquid) {
      return testnet ? '$liquidMempoolTestnet/address/$address' : '$liquidMempool/address/$address';
    } else {
      return testnet ? 'https://$mempoolapi/testnet/address/$address' : 'https://$mempoolapi/address/$address';
    }
  }

  ElectrumTypes? networkFromString(String text) {
    final network = text.toLowerCase().replaceAll(' ', '');
    switch (network) {
      case 'blockstream':
        return ElectrumTypes.blockstream;
      case 'bullbitcoin':
        return ElectrumTypes.bullbitcoin;
      case 'custom':
        return ElectrumTypes.custom;
      default:
        return null;
    }
  }

  LiquidElectrumTypes? liqNetworkFromString(String text) {
    final network = text.toLowerCase().replaceAll(' ', '');
    switch (network) {
      case 'blockstream':
        return LiquidElectrumTypes.blockstream;
      case 'custom':
        return LiquidElectrumTypes.custom;
      default:
        return null;
    }
  }

  String calculatePrice(int sats, Currency? currency) {
    if (currency == null) return '';
    if (testnet) return currency.getSymbol() + '0';
    return currency.getSymbol() +
        fiatFormatting(
          (sats / 100000000 * currency.price!).toStringAsFixed(2),
        );
  }

  String fiatFormatting(String fiatAmount) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    return currency.format(
      double.parse(fiatAmount),
    );
  }

  ({bool show, String? err}) showConfirmButton({required bool isLiquid}) {
    if (isLiquid) {
      if (tempLiquidNetwork == null) return (show: false, err: 'Network cannot be empty');
      return (show: true, err: null);
    }

    final temp = tempNetworkDetails;
    if (temp == null) return (show: false, err: '');

    if (temp.retry == 0) return (show: false, err: 'Retry cannot be 0');
    if (temp.stopGap == 0) return (show: false, err: 'Stop gap cannot be 0');
    if (temp.timeout == 0) return (show: false, err: 'Timeout cannot be 0');

    return (show: true, err: null);
  }
}
