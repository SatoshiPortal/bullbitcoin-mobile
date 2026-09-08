import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_funded_predecessor_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultHomeAlertCubit extends Cubit<String?> {
  final GetBullVaultFundedPredecessorUsecase _getFundedPredecessorUsecase;
  int _loadGeneration = 0;

  BullVaultHomeAlertCubit(this._getFundedPredecessorUsecase) : super(null);

  Future<void> load(List<Wallet> wallets) async {
    final generation = ++_loadGeneration;
    if (state != null && !wallets.any((wallet) => wallet.id == state)) {
      emit(null);
    }
    final result = await _getFundedPredecessorUsecase.execute(wallets);
    if (isClosed || generation != _loadGeneration) return;
    if (result case Ok(:final value)) emit(value);
  }
}
