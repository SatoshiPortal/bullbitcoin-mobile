import 'package:fees/fees.dart';

import '../spend.dart';

/// The fee modal needs display values; the owning flow needs the exact spend
/// it reviewed. Associate them without exposing spend authority to the modal.
final class SpendFeePreview {
  final _preparations =
      Expando<
        ({PreparedBitcoinSpend spend, String? address, NetworkFee? fee})
      >();

  BitcoinFeePreviewSlot project(
    BitcoinSpendPreview? preview, {
    String? address,
    NetworkFee? fee,
  }) {
    if (preview == null) return const BitcoinFeePreviewSlot();
    final prepared = preview.prepared;
    final slot = BitcoinFeePreviewSlot(
      feeSat: preview.fee.value.toInt(),
      unsignedPsbt: prepared.unsignedPsbt,
      txSize: prepared.txSize,
      recipientAmountsSat: [
        for (final amount in prepared.recipientAmountsSat) amount.value.toInt(),
      ],
      isToSelf: prepared.isToSelf,
    );
    _preparations[slot] = (spend: prepared, address: address, fee: fee);
    return slot;
  }

  PreparedBitcoinSpend? prepared(
    BitcoinFeePreviewSlot slot, {
    String? address,
    NetworkFee? fee,
  }) => switch (_preparations[slot]) {
    (spend: final spend, address: final original, fee: final rate)
        when address == original && fee == rate =>
      spend,
    _ => null,
  };
}
