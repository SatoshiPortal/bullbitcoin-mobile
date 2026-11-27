import 'package:meta/meta.dart';

import '../payout/payout_rail.dart';
import '../recipients/domain/entities/recipient_details.dart';
import 'recipient_pick_event.dart';
import 'recipient_pick_state.dart';

@immutable
sealed class RecipientPickEffect {
  const RecipientPickEffect();
}

/// Read [page] of the recipients of [query] (and [owner]); answer
/// [RecipientPickPageLoaded] for [attempt].
final class RecipientPickFetchPage extends RecipientPickEffect {
  final RecipientQuery query;
  final RecipientOwnership? owner;
  final int page;
  final int attempt;

  const RecipientPickFetchPage(this.query, this.owner, this.page, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is RecipientPickFetchPage &&
      other.query == query &&
      other.owner == owner &&
      other.page == page &&
      other.attempt == attempt;

  @override
  int get hashCode =>
      Object.hash(RecipientPickFetchPage, query, owner, page, attempt);

  @override
  String toString() => 'RecipientPickFetchPage(page $page, $attempt)';
}

/// Save [details]; answer [RecipientPickSaved] for [attempt].
final class RecipientPickSave extends RecipientPickEffect {
  final RecipientDetails details;
  final int attempt;

  const RecipientPickSave(this.details, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is RecipientPickSave &&
      identical(other.details, details) &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(RecipientPickSave, attempt);
}

/// Look for a saved recipient with the account of [details] (same rail and
/// identity, see `recipientIdentity`); answer [RecipientPickFound].
final class RecipientPickFind extends RecipientPickEffect {
  final RecipientDetails details;
  final int attempt;

  const RecipientPickFind(this.details, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is RecipientPickFind &&
      identical(other.details, details) &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(RecipientPickFind, attempt);
}
