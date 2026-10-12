import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_account_info_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/account_info_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class AccountInfoCubit extends Cubit<AccountInfoState> {
  final GetAccountInfoUsecase _getAccountInfoUsecase;

  AccountInfoCubit({required this._getAccountInfoUsecase})
    : super(const AccountInfoState());

  Future<void> loadAccountInfo() async {
    emit(state.copyWith(isLoading: true, failure: null));

    final result = await _getAccountInfoUsecase.execute();
    if (isClosed) return;

    emit(switch (result) {
      Ok(:final value) => state.copyWith(isLoading: false, accountInfo: value),
      Err(:final failure) => state.copyWith(isLoading: false, failure: failure),
    });
  }
}
