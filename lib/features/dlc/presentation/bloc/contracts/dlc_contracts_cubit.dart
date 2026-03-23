import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_contracts_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_contract_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/sign_and_submit_cets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_contracts_state.dart';
part 'dlc_contracts_cubit.freezed.dart';

class DlcContractsCubit extends Cubit<DlcContractsState> {
  DlcContractsCubit({
    required GetContractsUsecase getContractsUsecase,
    required GetContractUsecase getContractUsecase,
    required SignAndSubmitCetsUsecase signAndSubmitCetsUsecase,
  })  : _getContractsUsecase = getContractsUsecase,
        _getContractUsecase = getContractUsecase,
        _signAndSubmitCetsUsecase = signAndSubmitCetsUsecase,
        super(const DlcContractsState());

  final GetContractsUsecase _getContractsUsecase;
  final GetContractUsecase _getContractUsecase;
  final SignAndSubmitCetsUsecase _signAndSubmitCetsUsecase;

  Future<void> loadContracts() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final contracts = await _getContractsUsecase.execute();
      emit(state.copyWith(isLoading: false, contracts: contracts));
    } on Exception catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> refreshContract({required String dlcId}) async {
    try {
      final contract = await _getContractUsecase.execute(dlcId: dlcId);
      final updated =
          state.contracts.map((c) => c.id == dlcId ? contract : c).toList();
      emit(state.copyWith(contracts: updated, selectedContract: contract));
    } on Exception catch (e) {
      emit(state.copyWith(error: e));
    }
  }

  void selectContract(DlcContract contract) =>
      emit(state.copyWith(selectedContract: contract, error: null));

  /// Signs the CETs for an accepted DLC contract (maker role) and submits
  /// the signatures to the coordinator.  Progress is reflected in [signingStep].
  Future<void> signAndSubmitMaker({required String dlcId}) async {
    emit(state.copyWith(isActing: true, signingStep: null, error: null));
    try {
      await for (final event
          in _signAndSubmitCetsUsecase.executeMaker(dlcId: dlcId)) {
        if (event.isDone && event.completedContract != null) {
          final contract = event.completedContract!;
          final updated = state.contracts
              .map((c) => c.id == dlcId ? contract : c)
              .toList();
          emit(state.copyWith(
            isActing: false,
            signingStep: null,
            contracts: updated,
            selectedContract: contract,
          ));
        } else {
          emit(state.copyWith(signingStep: event.step));
        }
      }
    } catch (e) {
      emit(state.copyWith(
        isActing: false,
        signingStep: null,
        error: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  Future<void> refresh() => loadContracts();
}
