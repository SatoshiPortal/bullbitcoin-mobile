import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/fee_preview.dart';
import 'package:spend/spend.dart';

/// Unsigned previews of the payin to the quoted deposit at each fee preset;
/// never sent. Empty when the wallet can't build them.
class PreviewFeePresetsUsecase {
  final Spend _spend;

  const PreviewFeePresetsUsecase(this._spend);

  Future<Map<FeeSelection, BitcoinFeePreviewSlot>> execute(
    SpendPreviewShape shape,
    FeeOptions fees,
  ) async {
    switch (await _spend.previewBitcoinFeePresets(
      walletId: shape.walletId,
      recipients: spendPreviewRecipients(shape),
      presets: fees,
      replaceByFee: shape.replaceByFee,
      selectedInputs: shape.coins,
    )) {
      case Ok(:final value):
        final previews = SpendFeePreview();
        return {
          for (final MapEntry(key: selection, value: preview) in value.entries)
            selection: previews.project(preview),
        };
      case Err():
        return const {};
    }
  }
}

/// The one recipient of a payin preview: the quoted deposit and amount.
List<BitcoinTransactionRecipient> spendPreviewRecipients(
  SpendPreviewShape shape,
) => [
  BitcoinTransactionRecipient.fixed(
    address: shape.target.address,
    amountSat: Sats.fromInt(shape.target.amountSat),
  ),
];
