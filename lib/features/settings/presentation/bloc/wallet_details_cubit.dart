import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDetailsState {
  final BitcoinWalletPolicy? policy;
  final bool isLoadingPolicy;
  final SettingsFailure? failure;

  const WalletDetailsState({
    this.policy,
    this.isLoadingPolicy = false,
    this.failure,
  });
}

class WalletDetailsCubit extends Cubit<WalletDetailsState> {
  final GetWalletPolicyUsecase _getWalletPolicyUsecase;

  WalletDetailsCubit({required this._getWalletPolicyUsecase})
    : super(const WalletDetailsState());

  Future<void> loadPolicy(String walletId) async {
    emit(const WalletDetailsState(isLoadingPolicy: true));
    final result = await _getWalletPolicyUsecase.execute(walletId);
    if (isClosed) return;

    result.fold(
      (policy) => emit(WalletDetailsState(policy: policy)),
      (failure) => emit(WalletDetailsState(failure: failure)),
    );
  }
}
