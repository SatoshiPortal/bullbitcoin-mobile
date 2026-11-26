import 'package:bull_exchange/src/payin/domain/usecases/preview_fee_presets_usecase.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/fee_preview.dart';
import 'package:spend/spend.dart';

/// An unsigned preview of the payin to the quoted deposit at a fee the user
/// typed; never sent. An empty slot when the wallet can't build it.
class PreviewCustomFeeUsecase {
  final Spend _spend;

  const PreviewCustomFeeUsecase(this._spend);

  Future<BitcoinFeePreviewSlot> execute(
    SpendPreviewShape shape,
    NetworkFee fee,
  ) async {
    switch (await _spend.previewBitcoinFee(
      walletId: shape.walletId,
      recipients: spendPreviewRecipients(shape),
      networkFee: fee,
      replaceByFee: shape.replaceByFee,
      selectedInputs: shape.coins,
    )) {
      case Ok(:final value):
        return SpendFeePreview().project(value);
      case Err():
        return const BitcoinFeePreviewSlot();
    }
  }
}
