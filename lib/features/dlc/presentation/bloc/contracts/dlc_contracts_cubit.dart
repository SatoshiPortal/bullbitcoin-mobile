import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_contracts_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_contract_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/submit_signed_cets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_contracts_state.dart';
part 'dlc_contracts_cubit.freezed.dart';

class DlcContractsCubit extends Cubit<DlcContractsState> {
  DlcContractsCubit({
    required GetContractsUsecase getContractsUsecase,
    required GetContractUsecase getContractUsecase,
    required SubmitSignedCetsUsecase submitSignedCetsUsecase,
  })  : _getContractsUsecase = getContractsUsecase,
        _getContractUsecase = getContractUsecase,
        _submitSignedCetsUsecase = submitSignedCetsUsecase,
        super(const DlcContractsState());

  final GetContractsUsecase _getContractsUsecase;
  final GetContractUsecase _getContractUsecase;
  final SubmitSignedCetsUsecase _submitSignedCetsUsecase;

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
      final updated = state.contracts
          .map((c) => c.id == dlcId ? contract : c)
          .toList();
      emit(state.copyWith(contracts: updated, selectedContract: contract));
    } on Exception catch (e) {
      emit(state.copyWith(error: e));
    }
  }

  void selectContract(DlcContract contract) =>
      emit(state.copyWith(selectedContract: contract, error: null));

  Future<void> submitSignedCets({
    required String dlcId,
    /// TODO: derive signatures from wallet signing logic
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
    required String fundingSignaturesHex,
  }) async {
    emit(state.copyWith(isActing: true, error: null));
    try {
      final contract = await _submitSignedCetsUsecase.execute(
        dlcId: dlcId,
        cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
        refundSignatureHex: refundSignatureHex,
        fundingSignaturesHex: fundingSignaturesHex,
      );
      final updated = state.contracts
          .map((c) => c.id == dlcId ? contract : c)
          .toList();
      emit(state.copyWith(
        isActing: false,
        contracts: updated,
        selectedContract: contract,
      ));
    } on Exception catch (e) {
      emit(state.copyWith(isActing: false, error: e));
    }
  }

  Future<void> refresh() => loadContracts();
}
