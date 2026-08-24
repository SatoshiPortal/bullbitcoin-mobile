import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/update_wallet_signer_device_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDetailsState {
  final BitcoinWalletPolicy? policy;
  final bool isLoadingPolicy;
  final SettingsFailure? failure;
  final bool isUpdatingSignerDevice;
  final Wallet? updatedWallet;
  final SettingsFailure? signerUpdateFailure;

  const WalletDetailsState({
    this.policy,
    this.isLoadingPolicy = false,
    this.failure,
    this.isUpdatingSignerDevice = false,
    this.updatedWallet,
    this.signerUpdateFailure,
  });

  WalletDetailsState copyWith({
    BitcoinWalletPolicy? policy,
    bool? isLoadingPolicy,
    SettingsFailure? failure,
    bool clearFailure = false,
    bool? isUpdatingSignerDevice,
    Wallet? updatedWallet,
    SettingsFailure? signerUpdateFailure,
    bool clearSignerUpdateFailure = false,
  }) => WalletDetailsState(
    policy: policy ?? this.policy,
    isLoadingPolicy: isLoadingPolicy ?? this.isLoadingPolicy,
    failure: clearFailure ? null : failure ?? this.failure,
    isUpdatingSignerDevice:
        isUpdatingSignerDevice ?? this.isUpdatingSignerDevice,
    updatedWallet: updatedWallet ?? this.updatedWallet,
    signerUpdateFailure: clearSignerUpdateFailure
        ? null
        : signerUpdateFailure ?? this.signerUpdateFailure,
  );
}

class WalletDetailsCubit extends Cubit<WalletDetailsState> {
  final GetWalletPolicyUsecase _getWalletPolicyUsecase;
  final UpdateWalletSignerDeviceUsecase _updateWalletSignerDeviceUsecase;

  WalletDetailsCubit({
    required this._getWalletPolicyUsecase,
    required this._updateWalletSignerDeviceUsecase,
  }) : super(const WalletDetailsState());

  Future<void> loadPolicy(String walletId) async {
    emit(state.copyWith(isLoadingPolicy: true, clearFailure: true));
    final result = await _getWalletPolicyUsecase.execute(walletId);
    if (isClosed) return;

    result.fold(
      (policy) => emit(
        state.copyWith(
          policy: policy,
          isLoadingPolicy: false,
          clearFailure: true,
        ),
      ),
      (failure) =>
          emit(state.copyWith(isLoadingPolicy: false, failure: failure)),
    );
  }

  Future<void> updateSignerDevice({
    required String walletId,
    required String signerId,
    required SignerDeviceEntity? signerDevice,
  }) async {
    if (state.isUpdatingSignerDevice) return;

    emit(
      state.copyWith(
        isUpdatingSignerDevice: true,
        clearSignerUpdateFailure: true,
      ),
    );
    final result = await _updateWalletSignerDeviceUsecase.execute(
      walletId: walletId,
      signerId: signerId,
      signerDevice: signerDevice,
    );
    if (isClosed) return;

    result.fold(
      (wallet) => emit(
        state.copyWith(
          updatedWallet: wallet,
          isUpdatingSignerDevice: false,
          clearSignerUpdateFailure: true,
        ),
      ),
      (failure) => emit(
        state.copyWith(
          isUpdatingSignerDevice: false,
          signerUpdateFailure: failure,
        ),
      ),
    );
  }
}
