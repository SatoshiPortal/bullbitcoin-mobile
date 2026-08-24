import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_registration_options_usecase.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletRegistrationState {
  final bool isLoading;
  final List<WalletRegistrationOption> options;
  final SettingsFailure? failure;

  const WalletRegistrationState({
    this.isLoading = false,
    this.options = const [],
    this.failure,
  });
}

class WalletRegistrationCubit extends Cubit<WalletRegistrationState> {
  final GetWalletRegistrationOptionsUsecase
  _getWalletRegistrationOptionsUsecase;

  WalletRegistrationCubit(this._getWalletRegistrationOptionsUsecase)
    : super(const WalletRegistrationState());

  Future<void> load(Wallet wallet) async {
    emit(const WalletRegistrationState(isLoading: true));
    final result = await _getWalletRegistrationOptionsUsecase.execute(wallet);
    if (isClosed) return;
    result.fold(
      (options) => emit(WalletRegistrationState(options: options)),
      (failure) => emit(WalletRegistrationState(failure: failure)),
    );
  }
}
