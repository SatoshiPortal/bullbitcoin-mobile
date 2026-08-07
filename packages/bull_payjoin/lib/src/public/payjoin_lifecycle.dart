import 'package:bull_payjoin/src/domain/payjoin_failure.dart';
import 'package:bull_payjoin/src/public/payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract interface class PayjoinLifecycle {
  Payjoin get payjoin;

  @useResult
  Future<Result<void, PayjoinFailure>> resume();

  Future<void> dispose();
}
