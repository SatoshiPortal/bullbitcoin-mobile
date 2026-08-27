import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class VerifyExchangePayinUsecase {
  final WalletRepository _walletRepository;

  VerifyExchangePayinUsecase(this._walletRepository);

  Future<void> execute({
    required String psbtOrPset,
    required OrderSwapRecord record,
    required String walletId,
  }) async {
    final order = record.order;
    if (order == null) {
      throw const SendTransactionBuildFailure('Exchange order is missing');
    }
    try {
      final actualAmount = await _walletRepository.getAmountSentToAddress(
        psbtOrPset: psbtOrPset,
        address: order.payinAddress,
        walletId: walletId,
      );
      if (actualAmount != order.payinAmountSat.toInt()) {
        throw const SendTransactionBuildFailure(
          'Exchange payin output does not match the pinned order',
        );
      }
    } on SendFailure {
      rethrow;
    } catch (error) {
      throw SendTransactionBuildFailure(
        'Failed to verify Exchange payin: ${error.runtimeType}',
      );
    }
  }
}
