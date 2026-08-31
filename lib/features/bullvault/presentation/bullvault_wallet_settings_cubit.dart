import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultWalletSettingsCubit extends Cubit<BullVaultDetails?> {
  final GetBullVaultDetailsUsecase _getDetailsUsecase;

  BullVaultWalletSettingsCubit(this._getDetailsUsecase) : super(null);

  Future<void> load(String walletId) async {
    final result = await _getDetailsUsecase.execute(walletId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => value,
      Err() => null,
    });
  }
}
