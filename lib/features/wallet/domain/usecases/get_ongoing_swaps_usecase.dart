import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The swaps still in progress, newest first. A swap nothing has moved for
/// (an unpaid invoice, a lockup never sent) is not one.
class GetOngoingSwapsUsecase {
  final SwapStore _swapStore;

  GetOngoingSwapsUsecase({required this._swapStore});

  @useResult
  Future<Result<List<Swap>, WalletFailure>> execute() async {
    switch (await _swapStore.ongoing()) {
      case Ok(:final value):
        return Ok(
          value.where((swap) => !swap.isUnfunded).toList()
            ..sort((a, b) => b.creationTime.compareTo(a.creationTime)),
        );
      case Err(:final failure):
        log.warning('Ongoing swaps unavailable (${failure.runtimeType})');
        return Err(
          WalletUnexpectedFailure('ongoing swaps: ${failure.runtimeType}'),
        );
    }
  }
}
