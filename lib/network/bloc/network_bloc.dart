import 'dart:convert';

import 'package:bb_mobile/_pkg/electrum_test.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/network/bloc/event.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  NetworkBloc({
    required HiveStorage hiveStorage,
    required NetworkRepository networkRepository,
  })  : _hiveStorage = hiveStorage,
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

    on<NetworkDataSubscribe>((event, emit) async {
      await emit.forEach(
        _networkRepository.dataStream,
        onData: (NetworkRepoData _) => state.copyWith(networkData: _),
      );
    });

    add(InitNetworks());
  }

  final HiveStorage _hiveStorage;

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

  Future<void> _onToggleTestnet(
    ToggleTestnet event,
    Emitter<NetworkState> emit,
  ) async {
    final isTestnet = state.networkData.testnet;
    await Future.delayed(const Duration(milliseconds: 50));
    try {} catch (e) {
      emit(state.copyWith(errLoadingNetworks: e.toString()));
    }

    _networkRepository.setNetworkData(testnet: !isTestnet);
  }

  Future<void> _onUpdateStopGapAndSave(
    UpdateStopGapAndSave event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempNetworkDetails;
    if (network == null) return;

    final updatedConfig = network.copyWith(stopGap: event.gap);

    _networkRepository.setNetworkData(tempNetworkDetails: updatedConfig);

    await Future.delayed(const Duration(milliseconds: 50));
    add(NetworkConfigsSave(isLiq: false));
  }

  Future<void> _onNetworkTypeChanged(
    NetworkTypeChanged event,
    Emitter<NetworkState> emit,
  ) async {
    final network =
        state.networkData.networks.firstWhere((_) => _.type == event.type);

    _networkRepository.setNetworkData(
      tempNetwork: event.type,
      tempNetworkDetails: network,
    );
  }

  Future<void> _onLiquidNetworkTypeChanged(
    LiquidNetworkTypeChanged event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.liquidNetworks
        .firstWhere((_) => _.type == event.type);

    _networkRepository.setNetworkData(
      tempLiquidNetwork: event.type,
      tempLiquidNetworkDetails: network,
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

  Future<void> _onNetworkConfigsSave(
    NetworkConfigsSave event,
    Emitter<NetworkState> emit,
  ) async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    if (!event.isLiq) {
      if (state.networkData.tempNetwork == null) return;
      final networks = state.networkData.networks.toList();
      final tempNetwork = state.networkData.tempNetworkDetails;
      final checkedTempNetworkDetails = tempNetwork!.copyWith(
        mainnet: _checkURL(tempNetwork.mainnet),
        testnet: _checkURL(tempNetwork.testnet),
      );

      final sslRegex =
          RegExp(r'^ssl:\/\/([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\:[0-9]{2,5}$');
      if (!sslRegex.hasMatch(tempNetwork.mainnet)) {
        final String error = _networkLoadError(tempNetwork.mainnet);
        final String formattedError = error.isNotEmpty ? (': $error') : '';
        emit(
          state.copyWith(
            errLoadingNetworks: 'Invalid mainnet electrum URL$formattedError',
          ),
        );
        return;
      }
      if (!sslRegex.hasMatch(tempNetwork.testnet)) {
        final String error = _networkLoadError(tempNetwork.testnet);
        final String formattedError = error.isNotEmpty ? ': $error' : '';
        emit(
          state.copyWith(
            errLoadingNetworks: 'Invalid testnet electrum URL$formattedError',
          ),
        );
        return;
      }

      if (state.networkData.testnet) {
        final testnetElectrumLive = await isElectrumLive(tempNetwork.testnet);
        if (!testnetElectrumLive) {
          emit(
            state.copyWith(
              errLoadingNetworks:
                  'Check Testnet electrum URL. Could not connect to electrum.',
            ),
          );
          return;
        }
      } else {
        final mainnetElectrumLive = await isElectrumLive(tempNetwork.mainnet);
        if (!mainnetElectrumLive) {
          emit(
            state.copyWith(
              errLoadingNetworks:
                  'Check Mainnet electrum URL. Could not connect to electrum.',
            ),
          );
          return;
        }
      }

      final index = networks.indexWhere(
        (element) => element.type == state.networkData.tempNetwork,
      );
      networks.removeAt(index);
      networks.insert(index, checkedTempNetworkDetails);

      _networkRepository.setNetworkData(
        networks: networks,
        selectedNetwork: tempNetwork.type,
      );
      await Future.delayed(const Duration(milliseconds: 100));
      add(SetupBlockchain(isLiquid: false));
      return;
    }

    if (state.networkData.tempLiquidNetwork == null) return;
    final networks = state.networkData.liquidNetworks.toList();
    final tempNetwork = state.networkData.tempLiquidNetworkDetails;
    final index = networks.indexWhere(
      (element) => element.type == state.networkData.tempLiquidNetwork,
    );
    networks.removeAt(index);
    networks.insert(index, state.networkData.tempLiquidNetworkDetails!);

    _networkRepository.setNetworkData(
      liquidNetworks: networks,
      selectedLiquidNetwork: tempNetwork!.type,
    );

    await Future.delayed(const Duration(milliseconds: 100));
    add(SetupBlockchain(isLiquid: true));
  }

  Future<void> _onUpdateTempMainnet(
    UpdateTempMainnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(mainnet: event.mainnet);

    _networkRepository.setNetworkData(tempNetworkDetails: updatedConfig);
  }

  Future<void> _onUpdateTempTestnet(
    UpdateTempTestnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(testnet: event.testnet);

    _networkRepository.setNetworkData(tempNetworkDetails: updatedConfig);
  }

  void _onUpdateTempStopGap(
    UpdateTempStopGap event,
    Emitter<NetworkState> emit,
  ) {
    final network = state.networkData.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(stopGap: event.gap);

    _networkRepository.setNetworkData(tempNetworkDetails: updatedConfig);
  }

  Future<void> _onUpdateTempLiquidMainnet(
    UpdateTempLiquidMainnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempLiquidNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(mainnet: event.mainnet);

    _networkRepository.setNetworkData(tempLiquidNetworkDetails: updatedConfig);
  }

  Future<void> _onUpdateTempLiquidTestnet(
    UpdateTempLiquidTestnet event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempLiquidNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(testnet: event.testnet);

    _networkRepository.setNetworkData(tempLiquidNetworkDetails: updatedConfig);
  }

  Future<void> _onUpdateTempTimeout(
    UpdateTempTimeout event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(timeout: event.timeout);

    _networkRepository.setNetworkData(tempNetworkDetails: updatedConfig);
  }

  Future<void> _onUpdateTempRetry(
    UpdateTempRetry event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(retry: event.retry);

    _networkRepository.setNetworkData(tempNetworkDetails: updatedConfig);
  }

  Future<void> _onUpdateTempValidateDomain(
    UpdateTempValidateDomain event,
    Emitter<NetworkState> emit,
  ) async {
    final network = state.networkData.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig =
        network.copyWith(validateDomain: event.validateDomain);

    _networkRepository.setNetworkData(tempNetworkDetails: updatedConfig);
  }

  Future<void> _onResetTempNetwork(
    ResetTempNetwork event,
    Emitter<NetworkState> emit,
  ) async {
    final selectedNetwork = state.getNetwork();
    final selectedLiquidNetwork = state.getLiquidNetwork();

    _networkRepository.setNetworkData(
      tempNetworkDetails: selectedNetwork,
      tempLiquidNetworkDetails: selectedLiquidNetwork,
    );

    _networkRepository.resetNetworkData(
      tempNetwork: true,
      tempLiquidNetwork: true,
    );
  }

  String _checkURL(String url) {
    if (!url.contains('://')) return 'ssl/:/$url';
    return url;
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

  Future<void> _onLoadNetworks(
    LoadNetworks event,
    Emitter<NetworkState> emit,
  ) async {
    if (state.loadingNetworks) return;
    emit(state.copyWith(loadingNetworks: true));

    await _networkRepository.loadNetworks();

    emit(state.copyWith(loadingNetworks: false));
  }

  Future<void> _onSetupBlockchain(
    SetupBlockchain event,
    Emitter<NetworkState> emit,
  ) async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    final isTestnet = event.isTestnetLocal ?? state.networkData.testnet;

    final err = await _networkRepository.setupBlockchain(
      isLiquid: event.isLiquid,
      isTestnetLocal: isTestnet,
    );

    if (err != null) {
      if (!state.networkErrorOpened) {
        BBAlert.showErrorAlertPopUp(
          title: err.title ?? '',
          err: err.message,
          onClose: () => add(CloseNetworkError()),
          okButtonText: 'Change server',
          onRetry: () => add(RetryNetwork()),
        );
      }

      emit(
        state.copyWith(
          errLoadingNetworks: err.toString(),
          networkErrorOpened: true,
        ),
      );
    }

    emit(state.copyWith(networkConnected: true));
  }
}
