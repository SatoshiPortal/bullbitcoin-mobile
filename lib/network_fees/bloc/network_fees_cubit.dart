import 'dart:convert';

import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/state.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkFeesCubit extends Cubit<NetworkFeesState> {
  NetworkFeesCubit({
    required this.hiveStorage,
    required this.mempoolAPI,
    required this.networkCubit,
    this.defaultNetworkFeesCubit,
  }) : super(const NetworkFeesState()) {
    init();
  }

  final HiveStorage hiveStorage;
  final MempoolAPI mempoolAPI;
  final NetworkCubit networkCubit;
  final NetworkFeesCubit? defaultNetworkFeesCubit;

  @override
  void onChange(Change<NetworkFeesState> change) {
    super.onChange(change);
    if (defaultNetworkFeesCubit != null) return;
    hiveStorage.saveValue(
      key: StorageKeys.networkFees,
      value: jsonEncode(change.nextState.toJson()),
    );
  }

  Future<void> init() async {
    if (defaultNetworkFeesCubit != null) {
      emit(defaultNetworkFeesCubit!.state);
      return;
    }

    Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await hiveStorage.getValue(StorageKeys.networkFees);
    if (err != null) {
      loadFees();
      return;
    }

    final networkFees = NetworkFeesState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(networkFees);
    await Future.delayed(const Duration(milliseconds: 50));
    loadFees();
  }

  void loadFees() async {
    emit(state.copyWith(loadingFees: true, errLoadingFees: ''));
    final testnet = networkCubit.state.testnet;
    final (fees, err) = await mempoolAPI.getFees(testnet);
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingFees: err.toString(),
          loadingFees: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        feesList: fees,
        loadingFees: false,
      ),
    );
  }

  void updateManualFees(String fees) async {
    final feesInDouble = int.tryParse(fees);
    if (feesInDouble == null) {
      emit(
        state.copyWith(
          tempFees: 000,
          // tempSelectedFeesOption: 2,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      return;
    }

    emit(state.copyWith(tempFees: feesInDouble, tempSelectedFeesOption: 4));
    checkMinimumFees();
  }

  void feeOptionSelected(int index) {
    emit(state.copyWith(tempSelectedFeesOption: index));
    checkMinimumFees();
  }

  void checkFees() {
    if (state.selectedFeesOption == 4 && (state.fees == null || state.fees == 0))
      feeOptionSelected(2);
  }

  void checkMinimumFees() async {
    await Future.delayed(50.ms);
    final minFees = state.feesList!.last;
    const max = 50;

    if (state.tempFees != null && state.tempFees! < minFees && state.tempSelectedFeesOption == 4)
      emit(
        state.copyWith(
          errLoadingFees:
              "The selected fee is below the Bitcoin Network's minimum relay fee. Your transaction will likely never confirm. Please select a higher fee than $minFees sats/vbyte .",
          // tempSelectedFeesOption: 2,
        ),
      );
    else if (state.tempFees != null && state.tempFees! > max && state.tempSelectedFeesOption == 4)
      emit(
        state.copyWith(
          errLoadingFees:
              'The default selected fee is too high. Please select a lower fee than $max sats/vbyte .',
          // tempSelectedFeesOption: 2,
        ),
      );
    else
      emit(state.copyWith(errLoadingFees: ''));
  }

  void confirmFeeClicked() {
    if (state.tempFees == null && state.tempSelectedFeesOption == null) return;
    if (state.tempSelectedFeesOption != null) {
      if (state.tempFees == 4 && (state.tempFees == null || state.tempFees == 0)) {
        print('');
      } else {
        emit(state.copyWith(selectedFeesOption: state.tempSelectedFeesOption!, fees: null));
        if (state.tempSelectedFeesOption == 4 && state.tempFees != null && state.tempFees! <= 50)
          emit(state.copyWith(fees: state.tempFees));
      }
    }
    emit(state.copyWith(feesSaved: true));
    clearTempFeeValues();
  }

  void clearTempFeeValues() async {
    await Future.delayed(200.ms);
    emit(state.copyWith(tempFees: null, tempSelectedFeesOption: null, feesSaved: false));
  }
}
