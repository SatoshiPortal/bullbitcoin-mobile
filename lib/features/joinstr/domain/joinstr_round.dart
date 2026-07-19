import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

enum JoinstrRoundStatus { waiting, broadcast, failed }

/// A coinjoin round this device initiated or joined. Rounds live in memory
/// for the session; completed ones are also written to the persistent
/// history.
class JoinstrRound {
  final bool initiated;
  final int denominationSat;
  final int peers;
  final String relay;
  final int feeRateSatPerVb;

  /// Initiator's nostr public key; null for a round this device initiated,
  /// where the bindings generate the key internally.
  final String? publicKey;
  final int expiresAtUnixSec;
  final JoinstrRoundStatus status;
  final String? txId;
  final JoinstrException? error;

  const JoinstrRound({
    required this.initiated,
    required this.denominationSat,
    required this.peers,
    required this.relay,
    required this.feeRateSatPerVb,
    required this.expiresAtUnixSec,
    this.publicKey,
    this.status = JoinstrRoundStatus.waiting,
    this.txId,
    this.error,
  });

  bool get isWaiting => status == JoinstrRoundStatus.waiting;

  int secondsUntilExpiry(DateTime now) {
    final remaining = expiresAtUnixSec - now.millisecondsSinceEpoch ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  JoinstrRound completed(String txId) => JoinstrRound(
    initiated: initiated,
    denominationSat: denominationSat,
    peers: peers,
    relay: relay,
    feeRateSatPerVb: feeRateSatPerVb,
    publicKey: publicKey,
    expiresAtUnixSec: expiresAtUnixSec,
    status: JoinstrRoundStatus.broadcast,
    txId: txId,
  );

  JoinstrRound failed(JoinstrException error) => JoinstrRound(
    initiated: initiated,
    denominationSat: denominationSat,
    peers: peers,
    relay: relay,
    feeRateSatPerVb: feeRateSatPerVb,
    publicKey: publicKey,
    expiresAtUnixSec: expiresAtUnixSec,
    status: JoinstrRoundStatus.failed,
    error: error,
  );
}
