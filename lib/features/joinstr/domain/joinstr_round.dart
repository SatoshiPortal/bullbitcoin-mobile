import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

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
/// at once, each on its own input coin. Its [step] drives the timeline.
class JoinstrRound {
  /// Session-unique id so a specific round can be updated while others run.
  final int id;
  final bool initiated;
  final int denominationSat;
  final int peers;
  final String relay;
  final int feeRateSatPerVb;

  /// The wallet coin (`txid:vout`) this round spends.
  final String inputOutpoint;

  /// Initiator's nostr public key; null for a round this device initiated.
  final String? publicKey;
  final int expiresAtUnixSec;

  /// The latest progress step (one of [JoinstrRoundStep.timeline]). Terminal
  /// state is carried by [txId] (broadcast) and [error] (failed), so the
  /// timeline keeps showing the step the round reached even after it ends.
  final JoinstrRoundStep step;
  final String? txId;
  final JoinstrException? error;

  const JoinstrRound({
    required this.id,
    required this.initiated,
    required this.denominationSat,
    required this.peers,
    required this.relay,
    required this.feeRateSatPerVb,
    required this.inputOutpoint,
    required this.expiresAtUnixSec,
    this.publicKey,
    this.step = JoinstrRoundStep.connecting,
    this.txId,
    this.error,
  });

  bool get isWaiting => txId == null && error == null;
  bool get isBroadcast => txId != null;
  bool get isFailed => error != null;

  int secondsUntilExpiry(DateTime now) {
    final remaining = expiresAtUnixSec - now.millisecondsSinceEpoch ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  JoinstrRound advancedTo(JoinstrRoundStep step) => _copyWith(step: step);

  JoinstrRound completed(String txId) => _copyWith(txId: txId);

  JoinstrRound failed(JoinstrException error) => _copyWith(error: error);

  JoinstrRound _copyWith({
    JoinstrRoundStep? step,
    String? txId,
    JoinstrException? error,
  }) => JoinstrRound(
    id: id,
    initiated: initiated,
    denominationSat: denominationSat,
    peers: peers,
    relay: relay,
    feeRateSatPerVb: feeRateSatPerVb,
    inputOutpoint: inputOutpoint,
    publicKey: publicKey,
    expiresAtUnixSec: expiresAtUnixSec,
    step: step ?? this.step,
    txId: txId ?? this.txId,
    error: error ?? this.error,
  );
}
