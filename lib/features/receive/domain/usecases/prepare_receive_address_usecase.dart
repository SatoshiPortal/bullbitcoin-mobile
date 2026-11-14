import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared address use-case, which still throws
/// (a `GetReceiveAddressException`).
class PrepareReceiveAddressUsecase {
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;

  const PrepareReceiveAddressUsecase(this._getReceiveAddressUsecase);

  @useResult
  Future<Result<WalletAddress, ReceiveFailure>> execute({
    required String walletId,
    bool generateNew = false,
  }) async {
    try {
      return Ok(
        await _getReceiveAddressUsecase.execute(
          walletId: walletId,
          generateNew: generateNew,
        ),
      );
    } on Exception catch (e) {
      if (e is! GetReceiveAddressException || !e.reported) {
        log.warning('Receive address failed reason=unavailable');
      }
      return const Err(ReceiveAddressUnavailableFailure('unavailable'));
    }
  }
}
