import 'dart:convert';

import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/network.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'network_repository.freezed.dart';
part 'network_repository.g.dart';

@freezed
class NetworkRepoData with _$NetworkRepoData {
  const factory NetworkRepoData({
    @Default(false) bool testnet,
    @Default(20) int reloadWalletTimer,
    @Default([]) List<ElectrumNetwork> networks,
    @Default(ElectrumTypes.bullbitcoin) ElectrumTypes selectedNetwork,
    @Default([]) List<LiquidElectrumNetwork> liquidNetworks,
    @Default(LiquidElectrumTypes.blockstream)
    @Default(LiquidElectrumNetwork.bullbitcoin)
    LiquidElectrumTypes selectedLiquidNetwork,
    @Default(false) bool loadingNetworks,
    @Default('') String errLoadingNetworks,
    @Default(false) bool networkConnected,
    @Default(false) bool networkErrorOpened,

    // @Default(20) int stopGap,
    ElectrumTypes? tempNetwork,
    ElectrumNetwork? tempNetworkDetails,
    LiquidElectrumTypes? tempLiquidNetwork,
    LiquidElectrumNetwork? tempLiquidNetworkDetails,
    @Default(false) bool goToSettings,
  }) = _NetworkRepoData;
  const NetworkRepoData._();

  factory NetworkRepoData.fromJson(Map<String, dynamic> json) =>
      _NetworkRepoData.fromJson(json);
}

class NetworkRepository {
  NetworkRepository({
    required WalletNetwork walletNetwork,
    required HiveStorage hiveStorage,
  })  : _walletNetwork = walletNetwork,
        _hiveStorage = hiveStorage;

  var _data = const NetworkRepoData();

  Stream<NetworkRepoData> get dataStream => Stream.value(_data);
  NetworkRepoData get data => _data;

  final WalletNetwork _walletNetwork;
  final HiveStorage _hiveStorage;

  Future<Err?> init() async {
    final (result, err) =
        await _hiveStorage.getValue(StorageKeys.networkReposity);
    if (err != null) return err;

    _data = NetworkRepoData.fromJson(
      jsonDecode(result!) as Map<String, dynamic>,
    );

    return null;
  }

  Future save() async {
    await _hiveStorage.saveValue(
      key: StorageKeys.networkReposity,
      value: jsonEncode(_data.toJson()),
    );
  }

  Future toggleTestnet({required bool testnet}) async {
    _data = _data.copyWith(testnet: testnet);
    // this.testnet = testnet;
  }

  Future<Err?> setupBlockchain({bool? isLiquid, bool? isTestnetLocal}) async {
    final isTestnet = isTestnetLocal ?? _data.testnet;

    if (isLiquid == null || !isLiquid) {
      final selectedNetwork = getNetwork;
      if (selectedNetwork == null) return Err('Network not setup');

      final errBitcoin = await _walletNetwork.createBlockChain(
        isTestnet: isTestnet,
        stopGap: selectedNetwork.stopGap,
        timeout: selectedNetwork.timeout,
        retry: selectedNetwork.retry,
        url: isTestnet ? selectedNetwork.testnet : selectedNetwork.mainnet,
        validateDomain: selectedNetwork.validateDomain,
      );
      if (errBitcoin != null) return errBitcoin;
      return null;
    }

    if (isLiquid) {
      final selectedLiqNetwork = getLiquidNetwork;
      if (selectedLiqNetwork == null) return Err('Liquid Network not setup');

      final errLiquid = await _walletNetwork.createBlockChain(
        url:
            isTestnet ? selectedLiqNetwork.testnet : selectedLiqNetwork.mainnet,
        isTestnet: isTestnet,
      );
      if (errLiquid != null) return errLiquid;
      return null;
    }
    return null;
  }

  Future loadNetworks() async {
    if (_data.networks.isNotEmpty) {
      final net =
          _data.networks.firstWhere((_) => _.type == _data.selectedNetwork);

      _data = _data.copyWith(
        tempNetworkDetails: net,
        tempNetwork: net.type,
        selectedNetwork: net.type,
      );

      // final err = await setupBlockchain(isLiquid: false);
      // if (err != null) return err;
    } else {
      final newNetworks = [
        const ElectrumNetwork.defaultElectrum(),
        const ElectrumNetwork.bullbitcoin(),
        const ElectrumNetwork.custom(
          mainnet: 'ssl://$bbelectrumMain',
          testnet: 'ssl://$openelectrumTest',
        ),
      ];

      final net = newNetworks[2];

      _data = _data.copyWith(
        networks: newNetworks,
        tempNetworkDetails: net,
        tempNetwork: net.type,
        selectedNetwork: net.type,
      );

      // final err = await setupBlockchain(isLiquid: false);
      // if (err != null) return err;
    }

    if (_data.liquidNetworks.isNotEmpty) {
      var net = _data.liquidNetworks
          .firstWhere((_) => _.type == _data.selectedLiquidNetwork);
      final updatedLiqNetworks = _data.liquidNetworks.toList();
      if (_data.liquidNetworks.length == 2) {
        updatedLiqNetworks.insert(1, const LiquidElectrumNetwork.bullbitcoin());
        net = updatedLiqNetworks[1];
      }

      _data = _data.copyWith(
        tempLiquidNetworkDetails: net,
        tempLiquidNetwork: net.type,
        selectedLiquidNetwork: net.type,
        liquidNetworks: updatedLiqNetworks,
      );

      // tempLiquidNetworkDetails = net;
      // tempLiquidNetwork = net.type;
      // selectedLiquidNetwork = net.type;
      // liquidNetworks = updatedLiqNetworks;

      // final err = await setupBlockchain(isLiquid: true);
      // if (err != null) return err;
    } else {
      final newLiqNetworks = [
        const LiquidElectrumNetwork.blockstream(),
        const LiquidElectrumNetwork.bullbitcoin(),
        const LiquidElectrumNetwork.custom(
          mainnet: liquidElectrumUrl,
          testnet: liquidElectrumTestUrl,
        ),
      ];
      final selectedLiqNetwork = newLiqNetworks[1];

      _data = _data.copyWith(
        liquidNetworks: newLiqNetworks,
        tempLiquidNetworkDetails: selectedLiqNetwork,
        tempLiquidNetwork: selectedLiqNetwork.type,
        selectedLiquidNetwork: selectedLiqNetwork.type,
      );

      // liquidNetworks = newLiqNetworks;
      // tempLiquidNetworkDetails = selectedLiqNetwork;
      // tempLiquidNetwork = selectedLiqNetwork.type;
      // selectedLiquidNetwork = selectedLiqNetwork.type;
    }
  }

  bool get testnet => _data.testnet;

  ElectrumNetwork? get getNetwork {
    if (_data.networks.isEmpty) return null;
    return _data.networks.firstWhere((_) => _.type == _data.selectedNetwork);
  }

  LiquidElectrumNetwork? get getLiquidNetwork {
    if (_data.liquidNetworks.isEmpty) return null;
    return _data.liquidNetworks
        .firstWhere((_) => _.type == _data.selectedLiquidNetwork);
  }

  BBNetwork get getBBNetwork =>
      _data.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
  bdk.Network get getBdkNetwork =>
      _data.testnet ? bdk.Network.testnet : bdk.Network.bitcoin;

  String get getLiquidNetworkUrl {
    final network = getLiquidNetwork;
    if (network == null) return '';
    return network.getNetworkUrl(_data.testnet, split: false);
  }

  String get getNetworkUrl {
    final network = getNetwork;
    if (network == null) return '';
    return network.getNetworkUrl(_data.testnet);
  }

  double get pickLiquidFees {
    switch (_data.selectedLiquidNetwork) {
      case LiquidElectrumTypes.custom:
      case LiquidElectrumTypes.blockstream:
        return 0.1;
      case LiquidElectrumTypes.bullbitcoin:
        return 0.01; // 0.01; TODO: Sai for liquid testnet
    }
  }

  Future<Err?> saveNetworkConfig() async {
    return null;
  }
}
