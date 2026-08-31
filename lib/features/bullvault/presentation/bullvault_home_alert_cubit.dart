import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultHomeAlertCubit extends Cubit<String?> {
  final GetBullVaultDetailsUsecase _getDetailsUsecase;
  int _loadGeneration = 0;

  BullVaultHomeAlertCubit(this._getDetailsUsecase) : super(null);

  Future<void> load(List<Wallet> wallets) async {
    final generation = ++_loadGeneration;
    for (final wallet in wallets.where((wallet) => wallet.isBitcoin)) {
      final result = await _getDetailsUsecase.execute(wallet.id);
      if (isClosed || generation != _loadGeneration) return;
      if (result case Ok(value: final details?) when details.hasPreviousFunds) {
        final routeWalletId = switch (details.record.status) {
          BullVaultLifecycleStatus.active ||
          BullVaultLifecycleStatus.migrating => details.record.walletId,
          BullVaultLifecycleStatus.pending ||
          BullVaultLifecycleStatus.activating ||
          BullVaultLifecycleStatus.cancelled => details.record.previousVaultId,
        };
        if (routeWalletId != null) {
          emit(routeWalletId);
          return;
        }
      }
    }
    if (!isClosed && generation == _loadGeneration) emit(null);
  }
}
