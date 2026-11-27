import '../steps/lists_equal.dart';

import 'package:meta/meta.dart';

import '../recipients/domain/entities/recipient.dart';
import '../recipients/domain/entities/recipient_details.dart';
import 'payout_rail.dart';
import 'payout_requirement.dart';

/// Which recipients a flow may pay (composition §4.4): sell its one rail
/// and own accounts, withdraw its market's rails and own accounts, pay every
/// standard rail and any owner.
@immutable
final class RecipientFilter {
  final List<PayoutRail> rails;

  /// Null admits any owner.
  final RecipientOwnership? owner;

  const RecipientFilter({required this.rails, this.owner});

  bool admits(Recipient recipient) =>
      rails.contains(recipient.rail) &&
      switch (owner) {
        null => true,
        final RecipientOwnership owner => recipient.isOwner == owner.isOwner,
      };

  /// [recipient] chosen under this filter, or null when the filter doesn't
  /// admit it. The only way to make a [ChosenRecipient].
  ChosenRecipient? choose(Recipient recipient) =>
      admits(recipient) ? ChosenRecipient._(recipient) : null;

  @override
  bool operator ==(Object other) =>
      other is RecipientFilter &&
      other.owner == owner &&
      listsEqual(other.rails, rails);

  @override
  int get hashCode => Object.hash(owner, Object.hashAll(rails));
}

/// The output of the recipient pick step: a recipient a flow's filter
/// admitted, on its rail.
@immutable
final class ChosenRecipient {
  final Recipient recipient;

  const ChosenRecipient._(this.recipient);

  PayoutRail get rail => recipient.rail;

  /// What the rail needs before an order for [purpose] can pay it.
  List<PayoutRequirement> requirements(PayoutPurpose purpose) =>
      recipient.onRail.requirements(purpose);

  /// The same account on the rail's fallback (Confidential SEPA → SEPA), or
  /// null when the rail has none.
  ChosenRecipient? get fallback => switch (recipient.onRail.fallback) {
    null => null,
    final RecipientDetails details => ChosenRecipient._(
      recipient.withDetails(details),
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is ChosenRecipient &&
      other.recipient.recipientId == recipient.recipientId &&
      other.rail == rail;

  @override
  int get hashCode => Object.hash(recipient.recipientId, rail);

  @override
  String toString() => 'ChosenRecipient(${recipient.recipientId}, $rail)';
}
