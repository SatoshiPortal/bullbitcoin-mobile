import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin.freezed.dart';

/// - [completed]: a real payjoin proposal was negotiated and broadcast.
/// - [aborted]: no real payjoin happened — WE broadcast the original
///   transaction instead (below-minimum decline, manual "send without
///   payjoin", or expiry with an original available). The payment still
///   landed, just as a plain transaction; naming the outcome (aborted) not
///   the mechanism (a fallback broadcast) keeps this legible to the user
///   without implying anything went wrong with their payment.
/// - [expired]: the session died with nothing broadcast by us.
enum PayjoinStatus { started, requested, proposed, completed, aborted, expired }

@freezed
sealed class Payjoin with _$Payjoin {
  const factory Payjoin.receiver({
    @Default(PayjoinStatus.requested) PayjoinStatus status,
    required String id,
    required bool isTestnet,
    required String walletId,
    required String pjUri,
    required DateTime createdAt,
    required DateTime expiresAt,
    Uint8List? originalTxBytes,
    String? originalTxId,
    int? amountSat,
    String? proposalPsbt,
    String? txId,
  }) = PayjoinReceiver;
  const factory Payjoin.sender({
    @Default(PayjoinStatus.requested) PayjoinStatus status,
    required String uri,
    required bool isTestnet,
    required String walletId,
    required String originalPsbt,
    required String originalTxId,
    required int amountSat,
    required DateTime createdAt,
    required DateTime expiresAt,
    String? proposalPsbt,
    String? txId,
  }) = PayjoinSender;
  const Payjoin._();

  String get id => switch (this) {
    PayjoinReceiver(:final id) => id,
    PayjoinSender(:final uri) => uri,
  };

  /// Privacy-safe identifier for log lines. A sender's [id] IS the full
  /// BIP21 URI — address, amount and payjoin endpoint — which must never be
  /// logged (logs are user-shareable and SEVERE records reach Sentry). Hash
  /// it to the same opaque 16-hex-char shape as a receiver id, which is
  /// already a sha256 prefix of the pjUri and passes through unchanged so
  /// existing logs still correlate with stored sessions. The URI's `pj`/`rk`
  /// params make it high-entropy, so an unsalted hash is irreversible while
  /// staying stable across restarts (resumed-session logs keep correlating).
  String get logRef => switch (this) {
    PayjoinReceiver(:final id) => id,
    PayjoinSender(:final uri) => logRefForId(uri),
  };

  /// [logRef] for a raw session id string, for callers that only have the id
  /// (not the entity) — e.g. the repository's watcher machinery, keyed by
  /// payjoin id. A receiver id is already an opaque 16-hex-char sha256 prefix
  /// (passes through unchanged so logs still correlate); anything else is a
  /// sender's BIP21 URI (address+amount+endpoint) and MUST be hashed to the
  /// same shape before it can reach a log line.
  static String logRefForId(String id) {
    final isOpaqueReceiverId =
        id.length == 16 && RegExp(r'^[0-9a-f]{16}$').hasMatch(id);
    if (isOpaqueReceiverId) return id;
    return sha256.convert(utf8.encode(id)).toString().substring(0, 16);
  }

  bool get isCompleted => status == PayjoinStatus.completed;
  bool get isAborted => status == PayjoinStatus.aborted;
  bool get isExpired => status == PayjoinStatus.expired;
  bool get isOngoing => !isCompleted && !isAborted && !isExpired;

  /// Whether a manual "broadcast the original transaction" action would
  /// actually do anything right now, as opposed to silently no-op'ing (see
  /// PayjoinRepositoryImpl.tryBroadcastOriginalTransaction's guard, which
  /// this mirrors exactly). This is the single source of truth for BOTH
  /// halves of that feature — a manual-broadcast button's visibility and
  /// the action it triggers — so the two can never drift out of sync and
  /// show a button that would just do nothing when tapped (observed live:
  /// a stale-looking sender button re-broadcast an already-completed
  /// session).
  ///
  /// Role-specific, not just `proposalPsbt == null` (which stays true
  /// forever once a proposal is sent, even past a terminal state):
  /// - Receiver: once a proposal is SENT, the SENDER owns finalizing it for
  ///   as long as that takes — there is no dead-end here that would ever
  ///   need a manual retry.
  /// - Sender: once a proposal is RECEIVED, the repository's own handler
  ///   owns signing/broadcasting it, but if that AND its own internal
  ///   fallback both fail, the session ends up isExpired with proposalPsbt
  ///   still set and nothing left to retry it automatically — a manual
  ///   retry must still be possible there.
  bool get canManuallyBroadcastOriginal {
    if (isCompleted || isAborted) return false;
    return switch (this) {
      // originalTxBytes != null: a receiver still in `started` (no request
      //  received yet) has nothing to broadcast — broadcasting would hit a
      //  null originalTxBytes. The button only makes sense once the sender's
      //  original transaction is in hand.
      PayjoinReceiver(:final originalTxBytes) =>
        originalTxBytes != null && proposalPsbt == null,
      PayjoinSender() => proposalPsbt == null || isExpired,
    };
  }

  // Currently payjoin is always bitcoin, not liquid
  bool get isBitcoin => true;
  bool get isLiquid => false;
}
