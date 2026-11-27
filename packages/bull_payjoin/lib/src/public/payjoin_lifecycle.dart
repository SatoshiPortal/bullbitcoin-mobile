import 'package:bull_payjoin/src/domain/payjoin_failure.dart';
import 'package:bull_payjoin/src/public/payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract interface class PayjoinLifecycle {
  Payjoin get payjoin;

  @useResult
  Future<Result<void, PayjoinFailure>> resume();

  Future<void> dispose();

  /// Revokes now: roles and [resume] answer `Err` and nothing new starts. The
  /// future completes only once the native storage is confirmed closed.
  Future<void> suspend();

  /// Lets the next [resume] or role call open the storage again. A suspension
  /// whose stop is not yet confirmed stays suspended.
  void reopen();
}
