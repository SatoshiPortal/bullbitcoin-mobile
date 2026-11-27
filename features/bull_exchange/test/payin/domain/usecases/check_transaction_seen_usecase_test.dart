import 'package:bull_exchange/src/payin/domain/usecases/check_transaction_seen_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final class _Sessions extends Fake implements PayjoinSessions {
  final Result<List<PayjoinSession>, PayjoinFailure> byTx;
  final Result<String?, PayjoinFailure> visible;
  final asked = <String>[];

  _Sessions({required this.byTx, this.visible = const Ok(null)});

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String txid,
  ) async {
    asked.add('by tx $txid');
    return byTx;
  }

  @override
  Future<Result<String?, PayjoinFailure>> visibleTransaction(
    String sessionId,
  ) async {
    asked.add('visible $sessionId');
    return visible;
  }
}

PayjoinSenderSession _session() => PayjoinSenderSession(
  status: PayjoinStatus.requested,
  uri: 'pj-1',
  network: BitcoinNetwork.mainnet,
  walletId: 'w1',
  createdAt: DateTime.utc(2026, 11, 24),
  expiresAt: DateTime.utc(2030),
  amount: Sats.fromInt(1000),
  originalTransactionId: 'tx1',
);

Matcher _seen(bool seen) => isA<Ok<bool, ExchangeTransactionLookupFailure>>()
    .having((r) => r.value, 'value', seen);

final _cannotTell = isA<Err<bool, ExchangeTransactionLookupFailure>>();

void main() {
  test('a transaction its payjoin session sees is seen', () async {
    final sessions = _Sessions(
      byTx: Ok([_session()]),
      visible: const Ok('tx1'),
    );
    expect(
      await CheckTransactionSeenUsecase(sessions).execute('tx1'),
      _seen(true),
    );
    expect(sessions.asked, ['by tx tx1', 'visible pj-1']);
  });

  test('a session that sees no transaction is not seen', () async {
    final sessions = _Sessions(byTx: Ok([_session()]));
    expect(
      await CheckTransactionSeenUsecase(sessions).execute('tx1'),
      _seen(false),
    );
  });

  test('no session, or a failed read, can not tell', () async {
    expect(
      await CheckTransactionSeenUsecase(_Sessions(byTx: const Ok([])))
          .execute('tx1'),
      _cannotTell,
    );
    expect(
      await CheckTransactionSeenUsecase(
        _Sessions(
          byTx: Ok([_session()]),
          visible: const Err(PayjoinUnexpectedFailure('down')),
        ),
      ).execute('tx1'),
      _cannotTell,
    );
  });
}
