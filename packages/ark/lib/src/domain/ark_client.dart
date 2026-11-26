import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../ark.dart';

abstract interface class ArkClient {
  @useResult
  Future<Result<ArkSnapshot, ArkWalletFailure>> create(ArkAccountConfig config);
  @useResult
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(ArkAccountId account);
  Stream<Result<ArkSnapshot, ArkWalletFailure>> watch(ArkAccountId account);
  @useResult
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  });
  @useResult
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  );
  @useResult
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  );

  /// Broadcasts the due transactions of every exit in progress, at the fee
  /// rate the native wallet picks, paid from the on-chain fee reserve the
  /// user agreed to when starting the exit. Nothing due, nothing happens.
  /// Foreground only. Returns the progress operation, if one was admitted.
  @useResult
  Future<Result<ArkOperation?, ArkWalletFailure>> progressStartedExits(
    ArkAccountId account,
  );

  /// Claims every claimable exit within what the user authorized when they
  /// started it: its destination and the fee ceiling left. A claim whose fee
  /// is above that ceiling is not made; it stays for a manual review.
  /// Foreground only. Returns the claims admitted on this pass.
  @useResult
  Future<Result<List<ArkOperation>, ArkWalletFailure>> claimAuthorized(
    ArkAccountId account,
  );
  @useResult
  Future<Result<ArkReceiveDestination, ArkWalletFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  );

  /// When the server schedules its next round. Foreground only: it is a live
  /// server request and nothing in the background needs it.
  @useResult
  Future<Result<DateTime, ArkWalletFailure>> nextRound(ArkAccountId account);
  Future<void> close();
}
