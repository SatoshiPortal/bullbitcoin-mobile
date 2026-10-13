import 'package:bull_tor/tor.dart' as tor;
import '../recoverbull_failure.dart';

enum KeyServerStatus { unknown, connecting, online, offline }

const _unchangedFailure = Object();

/// Connection-only state; failureRevision distinguishes connection results
/// from readiness updates so progress cannot erase a vault failure.
final class RecoverBullConnection {
  final tor.TorConnectionState torConnection;
  final KeyServerStatus keyServerStatus;
  final int keyServerAttempt;
  final int keyServerAttempts;
  final RecoverBullFailure? failure;
  final int failureRevision;

  const RecoverBullConnection({
    this.torConnection = const tor.TorUninitialized(),
    this.keyServerStatus = KeyServerStatus.unknown,
    this.keyServerAttempt = 0,
    this.keyServerAttempts = 0,
    this.failure,
    this.failureRevision = 0,
  });

  RecoverBullConnection copyWith({
    tor.TorConnectionState? torConnection,
    KeyServerStatus? keyServerStatus,
    int? keyServerAttempt,
    int? keyServerAttempts,
    Object? failure = _unchangedFailure,
  }) => RecoverBullConnection(
    torConnection: torConnection ?? this.torConnection,
    keyServerStatus: keyServerStatus ?? this.keyServerStatus,
    keyServerAttempt: keyServerAttempt ?? this.keyServerAttempt,
    keyServerAttempts: keyServerAttempts ?? this.keyServerAttempts,
    failure: identical(failure, _unchangedFailure)
        ? this.failure
        : failure as RecoverBullFailure?,
    failureRevision:
        failureRevision + (identical(failure, _unchangedFailure) ? 0 : 1),
  );
}
