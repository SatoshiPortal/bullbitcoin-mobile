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
import 'package:rxdart/rxdart.dart';

part 'network_repository.freezed.dart';
part 'network_repository.g.dart';

@freezed
class NetworkRepoData with _$NetworkRepoData {
  const factory NetworkRepoData({
    @Default(false) bool testnet,
    @Default([]) List<ElectrumNetwork> networks,
    @Default(ElectrumTypes.bullbitcoin) ElectrumTypes selectedNetwork,
    @Default([]) List<LiquidElectrumNetwork> liquidNetworks,
    @Default(LiquidElectrumTypes.blockstream)
    LiquidElectrumTypes selectedLiquidNetwork,
    ElectrumTypes? tempNetwork,
    ElectrumNetwork? tempNetworkDetails,
    LiquidElectrumTypes? tempLiquidNetwork,
    LiquidElectrumNetwork? tempLiquidNetworkDetails,
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

  final _data =
      BehaviorSubject<NetworkRepoData>.seeded(const NetworkRepoData());

  Stream<NetworkRepoData> get dataStream => _data.asBroadcastStream();
  NetworkRepoData get data => _data.value;

  final WalletNetwork _walletNetwork;
  final HiveStorage _hiveStorage;

  void dispose() {
    _data.close();
  }

  Future<Err?> init() async {
    final (result, err) =
        await _hiveStorage.getValue(StorageKeys.networkReposity);
    if (err != null) return err;

    _data.add(
      NetworkRepoData.fromJson(
        jsonDecode(result!) as Map<String, dynamic>,
      ),
    );

    return null;
  }

  Future save() async {
    await _hiveStorage.saveValue(
      key: StorageKeys.networkReposity,
      value: jsonEncode(_data.value.toJson()),
    );
  }

  Future<Err?> setupBlockchain({bool? isLiquid, bool? isTestnetLocal}) async {
    final isTestnet = isTestnetLocal ?? _data.value.testnet;

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
    if (_data.value.networks.isNotEmpty) {
      final selectedNetwork = _data.value.networks
          .firstWhere((_) => _.type == _data.value.selectedNetwork);

      _data.add(
        _data.value.copyWith(
          tempNetworkDetails: selectedNetwork,
          tempNetwork: selectedNetwork.type,
          selectedNetwork: selectedNetwork.type,
        ),
      );

      await setupBlockchain(isLiquid: false);
    } else {
      final newNetworks = [
        const ElectrumNetwork.defaultElectrum(),
        const ElectrumNetwork.bullbitcoin(),
        const ElectrumNetwork.custom(
          mainnet: 'ssl://$bbelectrumMain',
          testnet: 'ssl://$openelectrumTest',
        ),
      ];

      final selectedNetwork = newNetworks[2];

      _data.add(
        _data.value.copyWith(
          networks: newNetworks,
          tempNetworkDetails: selectedNetwork,
          tempNetwork: selectedNetwork.type,
          selectedNetwork: selectedNetwork.type,
        ),
      );

      await setupBlockchain(isLiquid: false);
    }

    if (_data.value.liquidNetworks.isNotEmpty) {
      var selectedNetwork = _data.value.liquidNetworks
          .firstWhere((_) => _.type == _data.value.selectedLiquidNetwork);
      final updatedLiqNetworks = _data.value.liquidNetworks.toList();
      if (_data.value.liquidNetworks.length == 2) {
        updatedLiqNetworks.insert(1, const LiquidElectrumNetwork.bullbitcoin());
        selectedNetwork = updatedLiqNetworks[1];
      }

      _data.add(
        _data.value.copyWith(
          tempLiquidNetworkDetails: selectedNetwork,
          tempLiquidNetwork: selectedNetwork.type,
          selectedLiquidNetwork: selectedNetwork.type,
          liquidNetworks: updatedLiqNetworks,
        ),
      );

      await setupBlockchain(isLiquid: true);
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

      _data.add(
        _data.value.copyWith(
          liquidNetworks: newLiqNetworks,
          tempLiquidNetworkDetails: selectedLiqNetwork,
          tempLiquidNetwork: selectedLiqNetwork.type,
          selectedLiquidNetwork: selectedLiqNetwork.type,
        ),
      );

      await setupBlockchain(isLiquid: true);
    }
  }

  bool get testnet => _data.value.testnet;

  ElectrumNetwork? get getNetwork {
    if (_data.value.networks.isEmpty) return null;
    return _data.value.networks
        .firstWhere((_) => _.type == _data.value.selectedNetwork);
  }

  LiquidElectrumNetwork? get getLiquidNetwork {
    if (_data.value.liquidNetworks.isEmpty) return null;
    return _data.value.liquidNetworks
        .firstWhere((_) => _.type == _data.value.selectedLiquidNetwork);
  }

  BBNetwork get getBBNetwork =>
      _data.value.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
  bdk.Network get getBdkNetwork =>
      _data.value.testnet ? bdk.Network.testnet : bdk.Network.bitcoin;

  String get getLiquidNetworkUrl {
    final network = getLiquidNetwork;
    if (network == null) return '';
    return network.getNetworkUrl(_data.value.testnet, split: false);
  }

  String get getNetworkUrl {
    final network = getNetwork;
    if (network == null) return '';
    return network.getNetworkUrl(_data.value.testnet);
  }

  double get pickLiquidFees {
    switch (_data.value.selectedLiquidNetwork) {
      case LiquidElectrumTypes.custom:
      case LiquidElectrumTypes.blockstream:
        return 0.1;
      case LiquidElectrumTypes.bullbitcoin:
        return 0.01; // 0.01; TODO: Sai for liquid testnet
    }
  }

  void setNetworkData({
    bool? testnet,
    List<ElectrumNetwork>? networks,
    List<LiquidElectrumNetwork>? liquidNetworks,
    ElectrumNetwork? tempNetworkDetails,
    LiquidElectrumNetwork? tempLiquidNetworkDetails,
    ElectrumTypes? tempNetwork,
    LiquidElectrumTypes? tempLiquidNetwork,
    ElectrumTypes? selectedNetwork,
    LiquidElectrumTypes? selectedLiquidNetwork,
  }) {
    _data.add(
      _data.value.copyWith(
        testnet: testnet ?? _data.value.testnet,
        networks: networks ?? _data.value.networks,
        liquidNetworks: liquidNetworks ?? _data.value.liquidNetworks,
        tempNetworkDetails:
            tempNetworkDetails ?? _data.value.tempNetworkDetails,
        tempLiquidNetworkDetails:
            tempLiquidNetworkDetails ?? _data.value.tempLiquidNetworkDetails,
        tempNetwork: tempNetwork ?? _data.value.tempNetwork,
        tempLiquidNetwork: tempLiquidNetwork ?? _data.value.tempLiquidNetwork,
        selectedNetwork: selectedNetwork ?? _data.value.selectedNetwork,
        selectedLiquidNetwork:
            selectedLiquidNetwork ?? _data.value.selectedLiquidNetwork,
      ),
    );
  }

  void resetNetworkData({
    bool tempNetwork = false,
    bool tempLiquidNetwork = false,
  }) {
    _data.add(
      _data.value.copyWith(
        tempNetwork: tempNetwork ? null : _data.value.tempNetwork,
        tempLiquidNetwork:
            tempLiquidNetwork ? null : _data.value.tempLiquidNetwork,
      ),
    );
  }
}
