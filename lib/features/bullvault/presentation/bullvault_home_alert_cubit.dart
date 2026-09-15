import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_funded_predecessor_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/vault_recovery_notice.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the home screen has to say about vaults.
///
/// The two are independent: a retired vault still holding funds needs
/// attention, and a vault that has just been recovered is news. Neither is a
/// reason to hide the other.
final class BullVaultHomeAlertState {
  /// The retired vault that still holds funds, or null.
  final String? fundedPredecessorWalletId;

  /// Whether a recovery has put a vault on this device since the app started.
  final bool recovered;

  const BullVaultHomeAlertState({
    this.fundedPredecessorWalletId,
    this.recovered = false,
  });
}

final class BullVaultHomeAlertCubit extends Cubit<BullVaultHomeAlertState> {
  final GetBullVaultFundedPredecessorUsecase _getFundedPredecessorUsecase;
  final VaultRecoveryNotice _recoveryNotice;
  late final StreamSubscription<void> _recoveries;
  List<Wallet> _wallets = const [];
  int _loadGeneration = 0;

  BullVaultHomeAlertCubit(
    this._getFundedPredecessorUsecase,
    this._recoveryNotice,
  ) : super(const BullVaultHomeAlertState()) {
    // A recovery writes its wallets first and announces them after, so the
    // reload the writes cause runs before there is anything to announce.
    _recoveries = _recoveryNotice.recordings.listen((_) => load(_wallets));
  }

  @override
  Future<void> close() async {
    await _recoveries.cancel();
    return super.close();
  }

  Future<void> load(List<Wallet> wallets) async {
    _wallets = wallets;
    final generation = ++_loadGeneration;
    // Taken once and kept, so the announcement does not flash away on the next
    // rebuild and does not come back on the next launch.
    final recovered = state.recovered || _recoveryNotice.take();
    final current = state.fundedPredecessorWalletId;
    if (current != null && !wallets.any((wallet) => wallet.id == current)) {
      emit(BullVaultHomeAlertState(recovered: recovered));
    } else if (recovered != state.recovered) {
      emit(
        BullVaultHomeAlertState(
          fundedPredecessorWalletId: current,
          recovered: recovered,
        ),
      );
    }
    final result = await _getFundedPredecessorUsecase.execute(wallets);
    if (isClosed || generation != _loadGeneration) return;
    if (result case Ok(:final value)) {
      emit(
        BullVaultHomeAlertState(
          fundedPredecessorWalletId: value,
          recovered: recovered,
        ),
      );
    }
  }
}
