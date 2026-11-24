import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// A recipient as the recipient screens show it: everything shown comes
/// from its payout rail.
@immutable
final class RecipientViewModel {
  final Recipient recipient;

  const RecipientViewModel(this.recipient);

  String get id => recipient.recipientId;
  PayoutRail get rail => recipient.rail;
  RecipientType get type => rail.type;
  String? get label => recipient.label;
  bool? get isOwner => recipient.isOwner;
  Jurisdiction get jurisdiction => rail.market.jurisdiction;
  FiatCurrency get currency => rail.market.currency;
  String? get displayName => recipient.onRail.displayName;
  List<AccountRow> get accountRows => recipient.onRail.accountRows;

  @override
  bool operator ==(Object other) =>
      other is RecipientViewModel &&
      other.id == id &&
      other.rail == rail &&
      identical(other.recipient.details, recipient.details);

  @override
  int get hashCode => Object.hash(id, rail);

  @override
  String toString() => 'RecipientViewModel($id, $rail)';
}
