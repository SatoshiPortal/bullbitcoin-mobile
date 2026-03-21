part of 'dlc_contracts_cubit.dart';

@freezed
abstract class DlcContractsState with _$DlcContractsState {
  const factory DlcContractsState({
    @Default(false) bool isLoading,
    @Default(false) bool isActing,
    @Default([]) List<DlcContract> contracts,
    DlcContract? selectedContract,
    Exception? error,
  }) = _DlcContractsState;
  const DlcContractsState._();

  List<DlcContract> get activeContracts =>
      contracts.where((c) => c.isActive).toList();

  List<DlcContract> get closedContracts =>
      contracts.where((c) => c.isClosed).toList();

  List<DlcContract> get offeredContracts =>
      contracts.where((c) => c.status == DlcContractStatus.offered).toList();
}
