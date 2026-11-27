import 'dart:async';

import 'package:bull_exchange/src/payin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final class _Sessions extends Fake implements PayjoinSessions {
  final Result<PayjoinSession?, PayjoinFailure> stored;
  final List<Result<PayjoinSession, PayjoinFailure>> changes;
  final watched = <Set<String>>[];

  _Sessions(this.stored, [this.changes = const []]);

  @override
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(
    String sessionId,
  ) async => stored;

  @override
  Stream<Result<PayjoinSession, PayjoinFailure>> watch({
    Set<String>? sessionIds,
    String? walletId,
  }) {
    watched.add(sessionIds ?? {});
    return Stream.fromIterable(changes);
  }
}

PayjoinSenderSession _session(PayjoinStatus status) => PayjoinSenderSession(
  status: status,
  uri: 'pj-1',
  network: BitcoinNetwork.mainnet,
  walletId: 'w1',
  createdAt: DateTime.utc(2026, 11, 24),
  expiresAt: DateTime.utc(2030),
  amount: Sats.fromInt(1000),
  originalTransactionId: 'tx1',
);

void main() {
  test('the stored state comes first, then each change of the '
      'session', () async {
    final sessions = _Sessions(Ok(_session(PayjoinStatus.started)), [
      Ok(_session(PayjoinStatus.proposed)),
    ]);
    final progress = await WatchPayjoinUsecase(sessions)
        .execute('pj-1')
        .toList();
    expect(progress, hasLength(2));
    expect(sessions.watched, [
      {'pj-1'},
    ]);
  });

  test('a session that already ended is not watched', () async {
    final sessions = _Sessions(Ok(_session(PayjoinStatus.aborted)));
    final progress = await WatchPayjoinUsecase(sessions)
        .execute('pj-1')
        .toList();
    expect(progress, hasLength(1));
    expect(sessions.watched, isEmpty);
  });

  test('a failed read ends the watch', () async {
    final failed = _Sessions(const Err(PayjoinUnexpectedFailure('down')));
    expect(await WatchPayjoinUsecase(failed).execute('pj-1').toList(), isEmpty);
    final broken = _Sessions(Ok(_session(PayjoinStatus.started)), [
      const Err(PayjoinUnexpectedFailure('down')),
      Ok(_session(PayjoinStatus.proposed)),
    ]);
    expect(await WatchPayjoinUsecase(broken).execute('pj-1').toList(), [
      isA<PayjoinProgress>(),
    ]);
  });
}
