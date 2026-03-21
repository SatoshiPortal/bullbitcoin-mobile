import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/accept_offer_usecase.dart';
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
    required AcceptOfferUsecase acceptOfferUsecase,
    required SubmitSignedCetsUsecase submitSignedCetsUsecase,
  })  : _getContractsUsecase = getContractsUsecase,
        _getContractUsecase = getContractUsecase,
        _acceptOfferUsecase = acceptOfferUsecase,
        _submitSignedCetsUsecase = submitSignedCetsUsecase,
        super(const DlcContractsState());

  final GetContractsUsecase _getContractsUsecase;
  final GetContractUsecase _getContractUsecase;
  final AcceptOfferUsecase _acceptOfferUsecase;
  final SubmitSignedCetsUsecase _submitSignedCetsUsecase;

  Future<void> loadContracts({required String pubkey}) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final contracts = await _getContractsUsecase.execute(pubkey: pubkey);
      emit(state.copyWith(isLoading: false, contracts: contracts));
    } on Exception catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> refreshContract({required String contractId}) async {
    try {
      final contract = await _getContractUsecase.execute(contractId: contractId);
      final updated = state.contracts
          .map((c) => c.id == contractId ? contract : c)
          .toList();
      emit(state.copyWith(contracts: updated, selectedContract: contract));
    } on Exception catch (e) {
      emit(state.copyWith(error: e));
    }
  }

  void selectContract(DlcContract contract) =>
      emit(state.copyWith(selectedContract: contract, error: null));

  Future<void> acceptOffer({
    required String offerId,
    /// TODO: derive acceptHex from wallet signing logic
    required String acceptHex,
  }) async {
    emit(state.copyWith(isActing: true, error: null));
    try {
      final contract = await _acceptOfferUsecase.execute(
        offerId: offerId,
        acceptHex: acceptHex,
      );
      final updated = state.contracts
          .map((c) => c.id == offerId ? contract : c)
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

  Future<void> submitSignedCets({
    required String contractId,
    /// TODO: derive cetSignatureHex from wallet signing logic
    required String cetSignatureHex,
  }) async {
    emit(state.copyWith(isActing: true, error: null));
    try {
      final contract = await _submitSignedCetsUsecase.execute(
        contractId: contractId,
        cetSignatureHex: cetSignatureHex,
      );
      final updated = state.contracts
          .map((c) => c.id == contractId ? contract : c)
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

  Future<void> refresh({required String pubkey}) =>
      loadContracts(pubkey: pubkey);
}
