import 'package:meta/meta.dart';

import '../domain/catalog/market.dart';
import 'amount_entry_event.dart';

@immutable
sealed class AmountEntryEffect {
  const AmountEntryEffect();
}

/// Read the rate of [market]; answer [AmountRateArrived] for it.
final class AmountFetchRate extends AmountEntryEffect {
  final Market market;

  const AmountFetchRate(this.market);

  @override
  bool operator ==(Object other) =>
      other is AmountFetchRate && other.market == market;

  @override
  int get hashCode => Object.hash(AmountFetchRate, market);

  @override
  String toString() => 'AmountFetchRate($market)';
}

/// Push the KYC web view over the flow (never replace the flow); answer
/// [AmountDetourReturned] with the context read again.
final class AmountOpenKyc extends AmountEntryEffect {
  final Market market;

  const AmountOpenKyc(this.market);

  @override
  bool operator ==(Object other) =>
      other is AmountOpenKyc && other.market == market;

  @override
  int get hashCode => Object.hash(AmountOpenKyc, market);
}

/// Push the funding flow over this one; answer [AmountDetourReturned].
final class AmountOpenFunding extends AmountEntryEffect {
  final Market market;

  const AmountOpenFunding(this.market);

  @override
  bool operator ==(Object other) =>
      other is AmountOpenFunding && other.market == market;

  @override
  int get hashCode => Object.hash(AmountOpenFunding, market);
}
