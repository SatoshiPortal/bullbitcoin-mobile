import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

/// Temporary bridge from a [WalletFailure] back to a throw.
///
/// The wallet repository is now the try/catch boundary and returns
/// `Result<T, WalletFailure>`. Its callers in other features still throw, and
/// each one's real mapping — into that feature's own sealed family — belongs
/// to that feature's own #1895 change, not to a wallet PR that would have to
/// guess on its behalf.
///
/// Until then this keeps every unmigrated call site behaving exactly as it did:
/// a repository failure still surfaces as a throw, and the surrounding
/// try/catch still converts it. Every use is marked `TODO(#1895)`, so
/// `git grep 'TODO(#1895)'` is the remaining worklist.
///
/// Delete this class once that worklist is empty.
class WalletFailureException implements Exception {
  final WalletFailure failure;

  const WalletFailureException(this.failure);

  /// Deliberately only the failure's type: [WalletFailure.logMessage] is for
  /// the log, and this string can reach a report or a crash breadcrumb.
  @override
  String toString() => 'WalletFailureException(${failure.runtimeType})';
}
