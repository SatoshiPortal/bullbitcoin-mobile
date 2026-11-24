import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'exchange_environment.dart';

/// The exchange writes whose [WriteOutcomeUnknown] is journaled: each can
/// move money or create something on the account if sent twice, or leaves
/// the account in a state the app can't tell without a re-read.
enum UnknownWriteKind {
  buyConfirm('buy_confirm'),
  withdrawConfirm('withdraw_confirm'),
  accelerate('accelerate'),
  dcaCreate('dca_create'),
  limitOrderCreate('limit_order_create'),
  defaultWalletSave('default_wallet_save'),
  recipientCreate('recipient_create'),
  preferencesSave('preferences_save'),

  /// A buy, sell, pay or withdraw order create (`OrderCreateJournalRequest`).
  orderCreate('order_create');

  /// The stored value; never renamed.
  final String wire;

  const UnknownWriteKind(this.wire);

  static UnknownWriteKind? fromWire(String wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// How a re-read settled a journaled write.
enum UnknownWriteSettlement {
  /// The write took effect.
  applied('applied'),

  /// The re-read shows the write did not take effect.
  notApplied('not_applied'),

  /// The order ended, so the write no longer matters.
  orderEnded('order_ended'),

  /// No re-read settled it within [UnknownWrite.maxAge]; closed and logged so
  /// it stops holding the write gate. Whether it took effect stays unknown.
  expired('expired');

  final String wire;

  const UnknownWriteSettlement(this.wire);
}

/// What the app knows of a write that may have reached the exchange. The
/// [request] holds what was sent, minus secrets (no API key, no Interac
/// answer), as text.
@immutable
final class UnknownWriteDraft {
  final UnknownWriteKind kind;
  final ExchangeEnvironment environment;
  final int? sessionEpoch;
  final String? orderId;
  final Map<String, String> request;

  const UnknownWriteDraft({
    required this.kind,
    required this.environment,
    required this.request,
    this.sessionEpoch,
    this.orderId,
  });
}

/// An open journal entry: recorded, not settled yet.
@immutable
final class UnknownWrite {
  final String id;
  final UnknownWriteKind kind;
  final ExchangeEnvironment environment;
  final int? sessionEpoch;
  final String? orderId;
  final Map<String, String> request;
  final DateTime recordedAt;

  const UnknownWrite({
    required this.id,
    required this.kind,
    required this.environment,
    required this.request,
    required this.recordedAt,
    this.sessionEpoch,
    this.orderId,
  });

  /// How long an entry may stay open. Past it the next reconcile closes it as
  /// [UnknownWriteSettlement.expired] when its re-read still can't decide, and
  /// the write gate no longer waits for it.
  static const maxAge = Duration(hours: 24);

  bool isOverAge(DateTime now) => now.difference(recordedAt) > maxAge;
}

/// The journal could not be read or written.
final class UnknownWriteJournalFailure extends Failure {
  const UnknownWriteJournalFailure([super.logMessage]);
}

/// Persistent record of exchange writes that ended in an unknown outcome. An
/// entry is recorded before the caller moves on and leaves the open set only
/// when a re-read settles it; the write itself is never replayed.
abstract interface class UnknownWriteJournal {
  @useResult
  Future<Result<UnknownWrite, UnknownWriteJournalFailure>> record(
    UnknownWriteDraft draft,
  );

  /// The open entries of [environment], oldest first.
  @useResult
  Future<Result<List<UnknownWrite>, UnknownWriteJournalFailure>> open(
    ExchangeEnvironment environment,
  );

  /// Settles the entry [id]. Settling an entry that is already settled or
  /// unknown changes nothing.
  @useResult
  Future<Result<void, UnknownWriteJournalFailure>> settle(
    String id,
    UnknownWriteSettlement settlement,
  );
}
