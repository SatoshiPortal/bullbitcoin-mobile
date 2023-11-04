// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

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
    @Default(20) int stopGap,
    ElectrumTypes? tempNetwork,
  }) = _NetworkState;
  const NetworkState._();

  factory NetworkState.fromJson(Map<String, dynamic> json) => _$NetworkStateFromJson(json);

  ElectrumNetwork? getNetwork() {
    if (networks.isEmpty) return null;
    return networks.firstWhere((_) => _.type == selectedNetwork);
  }

  ElectrumNetwork? getTempOrSelectedNetwork() {
    if (networks.isEmpty) return null;
    if (tempNetwork == null) return getNetwork();
    return networks.firstWhere((_) => _.type == tempNetwork);
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
}
