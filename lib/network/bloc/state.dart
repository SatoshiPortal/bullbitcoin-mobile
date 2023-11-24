// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/electrum.dart';
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
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    bdk.Blockchain? blockchain,
    @Default(20) int reloadWalletTimer,
    @Default([]) List<ElectrumNetwork> networks,
    @Default(ElectrumTypes.bullbitcoin) ElectrumTypes selectedNetwork,
    @Default(false) bool loadingNetworks,
    @Default('') String errLoadingNetworks,
    @Default(false) bool networkConnected,
    @Default(false) bool networkErrorOpened,

    // @Default(20) int stopGap,
    ElectrumTypes? tempNetwork,
    ElectrumNetwork? tempNetworkDetails,
  }) = _NetworkState;
  const NetworkState._();

  factory NetworkState.fromJson(Map<String, dynamic> json) => _$NetworkStateFromJson(json);

  ElectrumNetwork? getNetwork() {
    if (networks.isEmpty) return null;
    return networks.firstWhere((_) => _.type == selectedNetwork);
  }

  ElectrumNetwork? getTempOrSelectedNetwork() {
    if (networks.isEmpty) return null;
    // return tempNetwork ?? selectedNetwork;
    if (tempNetwork == null) return getNetwork();
    final n = networks;
    final t = tempNetwork;

    return n.firstWhere((_) => _.type == t);
  }

  bdk.Network getBdkNetwork() {
    if (testnet) return bdk.Network.Testnet;
    return bdk.Network.Bitcoin;
  }

  BBNetwork getBBNetwork() {
    if (testnet) return BBNetwork.Testnet;
    return BBNetwork.Mainnet;
  }

  String explorerTxUrl(String txid) =>
      testnet ? 'https://$mempoolapi/testnet/tx/$txid' : 'https://$mempoolapi/tx/$txid';

  String explorerAddressUrl(String address) => testnet
      ? 'https://$mempoolapi/testnet/address/$address'
      : 'https://$mempoolapi/address/$address';

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
}
