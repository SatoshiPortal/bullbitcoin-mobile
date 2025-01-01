import 'dart:convert';

import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/network.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/network/bloc/event.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  NetworkBloc({
    required HiveStorage hiveStorage,
    required WalletNetwork walletNetwork,
    required NetworkRepository networkRepository,
  })  : _walletNetwork = walletNetwork,
        _hiveStorage = hiveStorage,
        _networkRepository = networkRepository,
        super(const NetworkState()) {
    on<InitNetworks>(_onInitNetworks);
    on<LoadNetworks>(_onLoadNetworks);
    on<ToggleTestnet>(_onToggleTestnet);
    on<UpdateStopGapAndSave>(_onUpdateStopGapAndSave);
    on<NetworkConfigsSave>(_onNetworkConfigsSave);
    on<NetworkTypeChanged>(_onNetworkTypeChanged);
    on<LiquidNetworkTypeChanged>(_onLiquidNetworkTypeChanged);
    on<CloseNetworkError>(_onCloseNetworkError);
    on<RetryNetwork>(_onRetryNetwork);
    on<UpdateTempMainnet>(_onUpdateTempMainnet);
    on<UpdateTempTestnet>(_onUpdateTempTestnet);
    on<UpdateTempLiquidMainnet>(_onUpdateTempLiquidMainnet);
    on<UpdateTempLiquidTestnet>(_onUpdateTempLiquidTestnet);
    on<UpdateTempStopGap>(_onUpdateTempStopGap);
    on<UpdateTempTimeout>(_onUpdateTempTimeout);
    on<UpdateTempRetry>(_onUpdateTempRetry);
    on<UpdateTempValidateDomain>(_onUpdateTempValidateDomain);
    on<ResetTempNetwork>(_onResetTempNetwork);
    on<SetupBlockchain>(_onSetupBlockchain);
    on<NetworkLoadError>(_onNetworkLoadError);
    on<UpdateMainnet>(_onUpdateMainnet);
    on<UpdateTestnet>(_onUpdateTestnet);

    add(InitNetworks());
  }

  final HiveStorage _hiveStorage;
  final WalletNetwork _walletNetwork;
  final NetworkRepository _networkRepository;

  @override
  void onChange(Change<NetworkState> change) {
    super.onChange(change);
    _hiveStorage.saveValue(
      key: StorageKeys.network,
      value: jsonEncode(
        change.nextState
            .copyWith(
              networkErrorOpened: false,
            )
            .toJson(),
      ),
    );
  }

  Future<void> _onInitNetworks(
    InitNetworks event,
    Emitter<NetworkState> emit,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await _hiveStorage.getValue(StorageKeys.network);
    if (err != null) {
      add(LoadNetworks());
      return;
    }

    final network =
        NetworkState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(network.copyWith(networkErrorOpened: false));
    await Future.delayed(const Duration(milliseconds: 100));
    add(LoadNetworks());
  }

  Future<void> _onLoadNetworks(
    LoadNetworks event,
    Emitter<NetworkState> emit,
  ) async {
    if (state.loadingNetworks) return;
    emit(state.copyWith(loadingNetworks: true));

    // ...existing loadNetworks logic...
    // Convert all emit calls to use the emit parameter
  }

  Future<void> _onToggleTestnet(
    ToggleTestnet event,
    Emitter<NetworkState> emit,
  ) async {
    final isTestnet = state.testnet;
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      // await setupBlockchain(isTestnetLocal: !isTestnet);
    } catch (e) {
      emit(state.copyWith(errLoadingNetworks: e.toString()));
    }
    emit(state.copyWith(testnet: !isTestnet));
  }

  Future<void> _onUpdateStopGapAndSave(
    UpdateStopGapAndSave event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;

    final updatedConfig = network.copyWith(stopGap: event.gap);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));

    await Future.delayed(const Duration(milliseconds: 50));
    add(NetworkConfigsSave(isLiq: false));
  }

  Future<void> _onNetworkTypeChanged(
    NetworkTypeChanged event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networks.firstWhere((_) => _.type == event.type);
    emit(
      state.copyWith(
        tempNetwork: event.type,
        tempNetworkDetails: network,
      ),
    );
  }

  Future<void> _onLiquidNetworkTypeChanged(
    LiquidNetworkTypeChanged event,
    Emitter<NetworkState> emit,
  ) async {
    final network =
        state.liquidNetworks.firstWhere((_) => _.type == event.type);
    emit(
      state.copyWith(
        tempLiquidNetwork: event.type,
        tempLiquidNetworkDetails: network,
      ),
    );
  }

  Future<void> _onCloseNetworkError(
    CloseNetworkError event,
    Emitter<NetworkState> emit,
  ) async {
    emit(state.copyWith(goToSettings: true));
    await Future.delayed(const Duration(milliseconds: 200));
    emit(state.copyWith(goToSettings: false));
    await Future.delayed(const Duration(seconds: 20));
    emit(state.copyWith(networkErrorOpened: false));
  }

  Future<void> _onRetryNetwork(
    RetryNetwork event,
    Emitter<NetworkState> emit,
  ) async {
    emit(state.copyWith(networkErrorOpened: false));
    await Future.delayed(const Duration(milliseconds: 100));
    add(SetupBlockchain());
  }

  Future<void> _onSetupBlockchain(
    SetupBlockchain event,
    Emitter<NetworkState> emit,
  ) async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    final isTestnet = event.isTestnetLocal ?? state.testnet;

    if (event.isLiquid == null || !event.isLiquid!) {
      final selectedNetwork = state.getNetwork();
      if (selectedNetwork == null) return;

      final errBitcoin = await _walletNetwork.createBlockChain(
        isTestnet: isTestnet,
        stopGap: selectedNetwork.stopGap,
        timeout: selectedNetwork.timeout,
        retry: selectedNetwork.retry,
        url: isTestnet ? selectedNetwork.testnet : selectedNetwork.mainnet,
        validateDomain: selectedNetwork.validateDomain,
      );

      if (errBitcoin != null) {
        if (!state.networkErrorOpened) {
          emit(state.copyWith(networkErrorOpened: true));
          BBAlert.showErrorAlertPopUp(
            title: errBitcoin.title ?? '',
            err: errBitcoin.message,
            onClose: () => add(CloseNetworkError()),
            okButtonText: 'Change server',
            onRetry: () => add(RetryNetwork()),
          );
          await Future.delayed(const Duration(seconds: 10));
          emit(state.copyWith(networkErrorOpened: false));
        }
        return;
      }
    }

    // ...existing liquid network setup logic...

    emit(state.copyWith(networkConnected: true));
  }

  Future<void> _onNetworkConfigsSave(
    NetworkConfigsSave event,
    Emitter<NetworkState> emit,
  ) async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));

    if (!event.isLiq) {
      if (state.tempNetwork == null) return;

      final networks = state.networks.toList();
      final tempNetwork = state.tempNetworkDetails!;
      final checkedTempNetworkDetails = tempNetwork.copyWith(
        mainnet: _checkURL(tempNetwork.mainnet),
        testnet: _checkURL(tempNetwork.testnet),
      );

      // Validation logic...
      if (!_validateNetwork(tempNetwork, emit)) return;

      final index =
          networks.indexWhere((element) => element.type == state.tempNetwork);
      networks.removeAt(index);
      networks.insert(index, checkedTempNetworkDetails);

      emit(
        state.copyWith(
          networks: networks,
          selectedNetwork: tempNetwork.type,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));
      add(SetupBlockchain(isLiquid: false));
      return;
    }

    // ... handle liquid network save logic ...
  }

  Future<void> _onUpdateTempMainnet(
    UpdateTempMainnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(mainnet: event.mainnet);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateTempTestnet(
    UpdateTempTestnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(testnet: event.testnet);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateMainnet(
    UpdateMainnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(mainnet: event.mainnet);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateTestnet(
    UpdateTestnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(testnet: event.testnet);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  void _onUpdateTempStopGap(
    UpdateTempStopGap event,
    Emitter<NetworkState> emit,
  ) {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(stopGap: event.gap);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateTempLiquidMainnet(
    UpdateTempLiquidMainnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempLiquidNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(mainnet: event.mainnet);
    emit(state.copyWith(tempLiquidNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateTempLiquidTestnet(
    UpdateTempLiquidTestnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempLiquidNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(testnet: event.testnet);
    emit(state.copyWith(tempLiquidNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateTempTimeout(
    UpdateTempTimeout event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(timeout: event.timeout);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateTempRetry(
    UpdateTempRetry event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(retry: event.retry);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  Future<void> _onUpdateTempValidateDomain(
    UpdateTempValidateDomain event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig =
        network.copyWith(validateDomain: event.validateDomain);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  Future<void> _onResetTempNetwork(
    ResetTempNetwork event,
    Emitter<NetworkState> emit,
  ) async {
    final selectedNetwork = state.getNetwork();
    final selectedLiquidNetwork = state.getLiquidNetwork();
    emit(
      state.copyWith(
        tempNetworkDetails: selectedNetwork,
        tempNetwork: null,
        tempLiquidNetwork: null,
        tempLiquidNetworkDetails: selectedLiquidNetwork,
      ),
    );
  }

  Future<void> _onNetworkLoadError(
    NetworkLoadError event,
    Emitter<NetworkState> emit,
  ) async {
    final error = _networkLoadError(event.url);
    emit(
      state.copyWith(
        errLoadingNetworks:
            'Invalid electrum URL${error.isNotEmpty ? ": $error" : ""}',
      ),
    );
  }

  // Helper methods
  String _checkURL(String url) {
    if (!url.contains('://')) return 'ssl://$url';
    return url;
  }

  bool _validateNetwork(ElectrumNetwork network, Emitter<NetworkState> emit) {
    final sslRegex =
        RegExp(r'^ssl:\/\/([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\:[0-9]{2,5}$');

    if (!sslRegex.hasMatch(network.mainnet)) {
      final error = _networkLoadError(network.mainnet);
      emit(
        state.copyWith(
          errLoadingNetworks:
              'Invalid mainnet electrum URL${error.isNotEmpty ? ": $error" : ""}',
        ),
      );
      return false;
    }
    // ... rest of validation logic ...
    return true;
  }

  String _networkLoadError(String url) {
    if (_isTorAddress(url)) return "Tor isn't supported";
    return '';
  }

  bool _isTorAddress(String url) {
    if (url.isEmpty) return false;
    final split = url.split(':');
    String cleanUrl = split.length > 1 ? split[1] : split[0];
    cleanUrl = cleanUrl.split('//').last;
    final torRegex = RegExp(r'^([a-z2-7]{16}|[a-zA-Z2-7]{56})\.onion$');
    return torRegex.hasMatch(cleanUrl);
  }

  // Add remaining event handlers following the same pattern...
}
