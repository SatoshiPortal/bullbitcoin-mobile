import 'package:bull_exchange/src/payin/domain/usecases/send_payin_usecase.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

import '../../payin_fixtures.dart';

final class _Spend extends FakeSpend {
  final Result<SpendBroadcastReceipt, SpendFailure> broadcast;
  final asked = <String>[];

  _Spend({required this.broadcast});

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) async {
    asked.add('broadcast ${signed.signedTransaction}');
    return broadcast;
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    asked.add('sign ${prepared.unsignedPsbt}');
    return Ok(SpendFixtures.signedBitcoin('signed-original'));
  }
}

final class _Sender extends Fake implements PayjoinSender {
  final Result<PayjoinSenderSession, PayjoinFailure> started;
  final asked = <StartPayjoinSender>[];

  _Sender(this.started);

  @override
  Future<Result<PayjoinSenderSession, PayjoinFailure>> start(
    StartPayjoinSender request,
  ) async {
    asked.add(request);
    return started;
  }
}

final class _Sessions extends Fake implements PayjoinSessions {}

final class _Labels extends Fake implements Labels {
  final stored = <String>[];

  @override
  Future<Result<Label, LabelFailure>> store(NewLabel label) async {
    stored.add('${label.reference} ${label.label} ${label.origin}');
    throw StateError('label written');
  }
}

SendPayinUsecase _usecase(
  Exchange exchange, {
  required _Spend spend,
  _Sender? sender,
  required _Labels labels,
}) => SendPayinUsecase(
  exchange,
  spend: spend,
  payjoinSender:
      sender ?? _Sender(const Err(PayjoinUnexpectedFailure('unused'))),
  payjoinSessions: _Sessions(),
  labels: labels,
);

PayinSend<PayinSpend> _send(PayinBuilt<PayinSpend> built, {SellOrder? order}) =>
    PayinSend<PayinSpend>(order ?? payinOrder(), payinTarget, 2, built);

final _signedBuilt = PayinBuilt<PayinSpend>(
  payinWalletSpend,
  'tx1',
  SignedBitcoinPayin<SignedBitcoinSpend>(SpendFixtures.signedBitcoin('raw')),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('a signed payin is broadcast through the gate and labelled as an '
      'exchange payin', () async {
    final spend = _Spend(
      broadcast: const Ok((txid: 'tx1', guarded: true, durable: true)),
    );
    final labels = _Labels();
    final answer = await _usecase(
      exchangeForTesting(),
      spend: spend,
      labels: labels,
    ).execute(payinSession, _send(_signedBuilt));
    await _settle();
    expect(answer.attempt, 2);
    expect(
      answer.answer,
      isA<Ok<PayinBroadcastOutcome, ExchangeWriteBusyFailure>>().having(
        (r) => r.value,
        'value',
        const PayinBroadcastAccepted('tx1'),
      ),
    );
    expect(spend.asked, ['broadcast raw']);
    expect(labels.stored, ['tx1 ${LabelSystem.exchangeSell.label} w1']);
  });

  test('an unknown broadcast is journaled as a payin of the session, and '
      'not labelled', () async {
    final journal = InMemoryUnknownWriteJournal();
    final labels = _Labels();
    final answer = await _usecase(
      exchangeForTesting(
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
      spend: _Spend(
        broadcast: const Err(SpendBroadcastOutcomeUnknownFailure()),
      ),
      labels: labels,
    ).execute(payinSession, _send(_signedBuilt));
    expect(
      answer.answer,
      isA<Ok<PayinBroadcastOutcome, ExchangeWriteBusyFailure>>().having(
        (r) => r.value,
        'value',
        isA<PayinBroadcastOutcomeUnknown>(),
      ),
    );
    final (entry, settlement) = journal.entries.single;
    expect(entry.kind, UnknownWriteKind.payin);
    expect(entry.environment, ExchangeEnvironment.mainnet);
    expect(entry.sessionEpoch, payinSession.epoch);
    expect(entry.orderId, 'o-1');
    expect(entry.request['txid'], 'tx1');
    expect(settlement, isNull);
    expect(labels.stored, isEmpty);
  });

  test('past the order deadline nothing is broadcast', () async {
    final spend = _Spend(
      broadcast: const Ok((txid: 'tx1', guarded: true, durable: true)),
    );
    final answer =
        await _usecase(
          exchangeForTesting(),
          spend: spend,
          labels: _Labels(),
        ).execute(
          payinSession,
          _send(_signedBuilt, order: payinOrder(deadline: DateTime.utc(2020))),
        );
    expect(
      answer.answer,
      isA<Ok<PayinBroadcastOutcome, ExchangeWriteBusyFailure>>().having(
        (r) => r.value,
        'value',
        const PayinBroadcastNotSent(PayinNotSentReason.deadlinePassed),
      ),
    );
    expect(spend.asked, isEmpty);
  });

  test('a payjoin payin is handed to a sender session on the session '
      'network', () async {
    final spend = _Spend(broadcast: const Err(SpendUnexpectedFailure()));
    final expiresAt = DateTime.utc(2030);
    final sender = _Sender(
      Ok(
        PayjoinSenderSession(
          status: PayjoinStatus.started,
          uri: 'pj-1',
          network: BitcoinNetwork.testnet,
          walletId: 'w1',
          createdAt: DateTime.utc(2026, 11, 24),
          expiresAt: expiresAt,
          amount: Sats.fromInt(100000),
          originalTransactionId: 'original-tx',
        ),
      ),
    );
    final labels = _Labels();
    final built = PayinBuilt<PayinSpend>(
      payinWalletSpend,
      'tx1',
      PayjoinPayin<PreparedBitcoinSpend>(
        prepared: SpendFixtures.preparedBitcoin(
          unsignedPsbt: 'unsigned',
          fee: Sats.fromInt(300),
        ),
        bip21: 'bitcoin:tb1q?pj=https://pj.example',
        amountSat: 100000,
        feeRateSatPerVb: 2.5,
        expiresAt: expiresAt,
      ),
    );
    final answer = await _usecase(
      exchangeForTesting(),
      spend: spend,
      sender: sender,
      labels: labels,
    ).execute(payinTestnetSession, _send(built));
    await _settle();
    expect(
      answer.answer,
      isA<Ok<PayinBroadcastOutcome, ExchangeWriteBusyFailure>>().having(
        (r) => r.value,
        'value',
        const PayinHandedToPayjoin('pj-1', 'original-tx'),
      ),
    );
    final request = sender.asked.single;
    expect(request.network, BitcoinNetwork.testnet);
    expect(request.walletId, 'w1');
    expect(request.bip21Uri, 'bitcoin:tb1q?pj=https://pj.example');
    expect(request.unsignedOriginalPsbt, 'unsigned');
    expect(spend.asked, ['sign unsigned']);
    expect(labels.stored, ['original-tx ${LabelSystem.exchangeSell.label} w1']);
  });
}
