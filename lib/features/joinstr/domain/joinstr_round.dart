import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'joinstr_round.freezed.dart';

/// The steps a coinjoin walks through, mirrored from the bindings so the UI can
/// render a progress timeline like joinstr-kmp and floresta_wallet. `done` and
/// `failed` are terminal.
enum JoinstrRoundStep {
  connecting,
  posting,
  outputRegistration,
  inputRegistration,
  broadcast,
  mined,
  done,
  failed,
  other;

  /// The ordered steps the timeline renders. We start the timeline at pool
  /// creation, so it carries more steps than the reference wallets (which only
  /// begin at input registration); `done`/`failed`/`other` are not rows.
  static const List<JoinstrRoundStep> timeline = [
    connecting,
    posting,
    outputRegistration,
    inputRegistration,
    broadcast,
    mined,
  ];
}

/// A coinjoin round this device initiated or joined. Several can be in flight
/// at once, each on its own input coin. Its [step] drives the timeline:
/// terminal state is carried by [txId] (broadcast) and [error] (failed), so
/// the timeline keeps showing the step the round reached even after it ends.
@freezed
abstract class JoinstrRound with _$JoinstrRound {
  const factory JoinstrRound({
    /// Session-unique id so a specific round can be updated while others run.
    required int id,
    required bool initiated,
    required int denominationSat,
    required int peers,
    required String relay,
    required int feeRateSatPerVb,

    /// The wallet coin (`txid:vout`) this round spends.
    required String inputOutpoint,
    required int expiresAtUnixSec,

    /// Initiator's nostr public key; null for a round this device initiated.
    String? publicKey,
    @Default(JoinstrRoundStep.connecting) JoinstrRoundStep step,
    String? txId,
    JoinstrException? error,
  }) = _JoinstrRound;

  const JoinstrRound._();

  bool get isWaiting => txId == null && error == null;
  bool get isBroadcast => txId != null;
  bool get isFailed => error != null;

  int secondsUntilExpiry(DateTime now) =>
      Joinstr.secondsUntilExpiry(expiresAtUnixSec, now);

  JoinstrRound advancedTo(JoinstrRoundStep step) => copyWith(step: step);

  JoinstrRound completed(String txId) => copyWith(txId: txId);

  JoinstrRound failed(JoinstrException error) => copyWith(error: error);
}
