import '../../payout/payout_rail.dart';
import '../entities/order.dart';
import 'jurisdiction.dart';
import 'kyc_policy.dart';

/// What the exchange offers for one fiat currency.
///
/// The funding rails (funding methods) of the market join this record when
/// they become types of their own.
final class Market {
  final FiatCurrency currency;
  final Jurisdiction jurisdiction;
  final KycPolicy kyc;

  const Market({
    required this.currency,
    required this.jurisdiction,
    required this.kyc,
  });

  /// The rails that pay out in this market, eligibility-only ones included.
  List<PayoutRail> get payoutRails => PayoutRails.ofMarket(this);

  @override
  String toString() => 'Market(${currency.code})';
}
