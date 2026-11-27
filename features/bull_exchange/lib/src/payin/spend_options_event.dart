import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:sync/sync.dart' show Coin;

import 'spend_options_state.dart';

@immutable
sealed class SpendOptionsEvent {
  const SpendOptionsEvent();
}

final class SpendFeesLoaded extends SpendOptionsEvent {
  final int attempt;
  final FeeOptions fees;

  const SpendFeesLoaded(this.attempt, this.fees);
}

final class SpendFeesFailed extends SpendOptionsEvent {
  final int attempt;

  const SpendFeesFailed(this.attempt);
}

final class SpendRetryPressed extends SpendOptionsEvent {
  const SpendRetryPressed();
}

/// The quote the previews price changed (a new order or a refresh).
final class SpendTargetSet extends SpendOptionsEvent {
  final SpendPreviewTarget target;

  const SpendTargetSet(this.target);
}

/// The fee sheet opened: price every preset.
final class SpendPresetPreviewsRequested extends SpendOptionsEvent {
  const SpendPresetPreviewsRequested();
}

/// The custom-fee field settled on [fee]: price it.
final class SpendCustomPreviewRequested extends SpendOptionsEvent {
  final NetworkFee fee;

  const SpendCustomPreviewRequested(this.fee);
}

final class SpendPresetsPreviewed extends SpendOptionsEvent {
  final int epoch;
  final Map<FeeSelection, BitcoinFeePreviewSlot> slots;

  const SpendPresetsPreviewed(this.epoch, this.slots);
}

final class SpendCustomPreviewed extends SpendOptionsEvent {
  final int epoch;
  final NetworkFee fee;
  final BitcoinFeePreviewSlot slot;

  const SpendCustomPreviewed(this.epoch, this.fee, this.slot);
}

/// A preset tile was picked.
final class SpendFeePicked extends SpendOptionsEvent {
  final FeeSelection selection;

  const SpendFeePicked(this.selection);
}

/// The custom-fee field holds [fee]: custom is selected, the previous
/// choice kept until the sheet closes.
final class SpendCustomFeeArmed extends SpendOptionsEvent {
  final NetworkFee fee;

  const SpendCustomFeeArmed(this.fee);
}

/// The custom-fee field was cleared.
final class SpendCustomFeeDisarmed extends SpendOptionsEvent {
  const SpendCustomFeeDisarmed();
}

/// The fee sheet closed without a preset: keep the typed fee when it clears
/// the relay floor, else go back to the previous choice.
final class SpendCustomFeeFinalized extends SpendOptionsEvent {
  const SpendCustomFeeFinalized();
}

final class SpendRbfChanged extends SpendOptionsEvent {
  final bool enabled;

  const SpendRbfChanged({required this.enabled});
}

final class SpendPayjoinChanged extends SpendOptionsEvent {
  final bool enabled;

  const SpendPayjoinChanged({required this.enabled});
}

/// The coin selection opened: read the wallet's coins.
final class SpendCoinsRequested extends SpendOptionsEvent {
  const SpendCoinsRequested();
}

final class SpendCoinsRead extends SpendOptionsEvent {
  /// Null when the wallet could not list them.
  final List<Coin>? coins;

  const SpendCoinsRead(this.coins);
}

/// The coins the user picked; empty lets the wallet choose.
final class SpendCoinsPicked extends SpendOptionsEvent {
  final List<Coin> coins;

  const SpendCoinsPicked(this.coins);
}
