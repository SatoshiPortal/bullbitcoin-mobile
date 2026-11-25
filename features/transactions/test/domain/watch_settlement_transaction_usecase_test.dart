import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transactions/testing.dart';

import '../presentation/animation_fixtures.dart';

class _MockGet extends Mock implements GetWalletTransactionUsecase {}

class _MockWatch extends Mock implements WatchWalletTransactionByTxIdUsecase {}

void main() {
  const target = TransactionSettlementTarget(walletId: 'wallet', txId: 'tx');
  late _MockGet get;
  late _MockWatch watch;
  late StreamController<WalletTransaction> revisions;
  late Completer<Result<WalletTransaction?, TransactionFailure>> read;

  setUp(() {
    get = _MockGet();
    watch = _MockWatch();
    revisions = StreamController<WalletTransaction>();
    read = Completer();
    when(
      () => watch.execute(
        walletId: any(named: 'walletId'),
        txId: any(named: 'txId'),
      ),
    ).thenAnswer((_) => revisions.stream);
    when(
      () => get.execute(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) => read.future);
  });

  test('emits the current transaction, then every revision', () async {
    final emitted = <WalletTransaction>[];
    final sub = WatchSettlementTransactionUsecase(
      get,
      watch,
    ).execute(target).listen(emitted.add);
    read.complete(Ok(walletTx('tx')));
    await Future<void>.delayed(Duration.zero);
    revisions.add(walletTx('tx', confirmed: true));
    await Future<void>.delayed(Duration.zero);
    expect(emitted.map((t) => t.isConfirmed), [false, true]);
    await sub.cancel();
    expect(revisions.hasListener, isFalse);
  });

  test('a revision seen first is not overwritten by a slower read', () async {
    final emitted = <WalletTransaction>[];
    final sub = WatchSettlementTransactionUsecase(
      get,
      watch,
    ).execute(target).listen(emitted.add);
    revisions.add(walletTx('tx', confirmed: true));
    await Future<void>.delayed(Duration.zero);
    read.complete(Ok(walletTx('tx')));
    await Future<void>.delayed(Duration.zero);
    expect(emitted.map((t) => t.isConfirmed), [true]);
    await sub.cancel();
  });

  test('an unavailable read leaves the observation active', () async {
    final emitted = <WalletTransaction>[];
    final sub = WatchSettlementTransactionUsecase(
      get,
      watch,
    ).execute(target).listen(emitted.add);
    read.complete(const Err(TransactionNotFoundFailure()));
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    revisions.add(walletTx('tx'));
    await Future<void>.delayed(Duration.zero);
    expect(emitted, hasLength(1));
    await sub.cancel();
  });
}
