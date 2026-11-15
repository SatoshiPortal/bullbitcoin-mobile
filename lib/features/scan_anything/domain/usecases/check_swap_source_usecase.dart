import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class CheckSwapSourceUsecase {
  final GetWalletsUsecase _getWalletsUsecase;

  const CheckSwapSourceUsecase({required this._getWalletsUsecase});

  Future<bool> execute({required bool fromLiquid}) async {
    try {
      return switch (await _getWalletsUsecase.execute()) {
        Ok(:final value) => value.any(
          (wallet) => wallet.isLiquid == fromLiquid && wallet.signsLocally,
        ),
        Err() => false,
      };
    } catch (e) {
      log.warning('Scan anything: swap source unavailable (${e.runtimeType})');
      return false;
    }
  }
}
