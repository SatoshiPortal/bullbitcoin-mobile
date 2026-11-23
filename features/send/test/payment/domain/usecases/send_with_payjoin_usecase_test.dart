import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:send/src/payment/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:primitives/primitives.dart' as core;
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletKey;

class _MockPayjoinSender extends Mock implements PayjoinSender {}

PayjoinSenderSession _session() => PayjoinSenderSession(
  status: PayjoinStatus.requested,
  uri: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
  network: BitcoinNetwork.mainnet,
  walletId: 'wallet-1',
  amount: Sats.fromInt(10000),
  originalTransactionId: 'original-txid',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

Future<core.Result<PayjoinSenderSession, SendFailure>> _start(
  PayjoinSender sender,
) => SendWithPayjoinUsecase(sender, _SigningSpend()).execute(
  walletId: 'wallet-1',
  network: BitcoinNetwork.mainnet,
  bip21: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
  prepared: SpendFixtures.preparedBitcoin(
    unsignedPsbt: 'cHNidP8=',
    fee: Sats.zero,
  ),
  amountSat: 10000,
  networkFeesSatPerVb: 2,
);

void main() {
  test(
    'admission receives the identical reviewed spend and signed original',
    () async {
      final sender = _MockPayjoinSender();
      final spend = _HandoffSpend();
      final prepared = SpendFixtures.preparedBitcoin(
        unsignedPsbt: 'exact-review',
        fee: Sats.fromInt(200),
      );
      when(() => sender.start(any())).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.single as StartPayjoinSender;
        expect(request.unsignedOriginalPsbt, prepared.unsignedPsbt);
        final original = request.preparedOriginal;
        expect(original?.signedPsbt, 'exact-signature');
        if (original == null) fail('expected a prepared original');
        final result = await original.admit(
          sessionId: 'session',
          persist: () async => fail('refused admission cannot persist'),
        );
        expect(result, isA<Err<void, PayjoinFailure>>());
        return const Err(PayjoinSpendBlockedFailure(busy: true));
      });

      final result = await SendWithPayjoinUsecase(sender, spend).execute(
        walletId: 'wallet-1',
        network: BitcoinNetwork.mainnet,
        bip21: 'bitcoin:recipient',
        prepared: prepared,
        amountSat: 10000,
        networkFeesSatPerVb: 2,
      );

      expect((result as Err).failure, isA<SendSpendBlockedFailure>());
      expect(spend.signedFrom, same(prepared));
      expect(spend.admittedFrom, same(prepared));
    },
  );

  test(
    'proposal retry forwards only the retained session id and maps refusal',
    () async {
      final sender = _MockPayjoinSender();
      when(() => sender.retryProposal('same-session'))
          .thenAnswer((_) async => const Err(PayjoinSpendBlockedFailure()));
      final result = await RetryPayjoinProposalUsecase(sender)
          .execute('same-session');
      expect(result, isA<core.Err<PayjoinSession, SendFailure>>());
      expect((result as core.Err).failure, isA<SendPayjoinPausedFailure>());
      verify(() => sender.retryProposal('same-session')).called(1);
      verifyNoMoreInteractions(sender);
    },
  );

  test('regtest reaches the sender as a concrete network', () async {
    final sender = _MockPayjoinSender();
    StartPayjoinSender? captured;
    when(() => sender.start(any())).thenAnswer((call) async {
      captured = call.positionalArguments.first as StartPayjoinSender;
      return const Err(PayjoinUnavailableFailure());
    });
    final result = await SendWithPayjoinUsecase(sender, _SigningSpend())
        .execute(
          walletId: 'regtest-wallet',
          network: BitcoinNetwork.regtest,
          bip21: 'bitcoin:bcrt1unused?pj=https://localhost:8040/fixture',
          prepared: SpendFixtures.preparedBitcoin(
            unsignedPsbt: 'unused',
            fee: Sats.zero,
          ),
          amountSat: 10000,
          networkFeesSatPerVb: 1,
        );
    expect(result, isA<Err>());
    expect((result as Err).failure, isA<SendPayjoinUnavailableFailure>());
    expect(captured?.network, BitcoinNetwork.regtest);
    verify(() => sender.start(any())).called(1);
  });

  setUpAll(() {
    // StartPayjoinSender is a final class, so mocktail needs a real instance
    // as the fallback rather than a Fake subclass.
    registerFallbackValue(
      StartPayjoinSender(
        walletId: 'wallet-1',
        network: BitcoinNetwork.mainnet,
        bip21Uri: 'bitcoin:bc1qaddress',
        unsignedOriginalPsbt: 'cHNidP8=',
        amount: Sats.fromInt(1),
        feeRate: FeeRate(1),
      ),
    );
  });

  test('returns the started session', () async {
    final sender = _MockPayjoinSender();
    final session = _session();
    when(() => sender.start(any())).thenAnswer(
      (_) async => Ok<PayjoinSenderSession, PayjoinFailure>(session),
    );

    final result = await _start(sender);

    expect(result, isA<core.Ok<PayjoinSenderSession, SendFailure>>());
    expect(
      (result as core.Ok<PayjoinSenderSession, SendFailure>).value,
      session,
    );
  });

  for (final busy in [true, false]) {
    test('a refused spend keeps its reason: busy=$busy', () async {
      final sender = _MockPayjoinSender();
      when(() => sender.start(any())).thenAnswer(
        (_) async => Err<PayjoinSenderSession, PayjoinFailure>(
          PayjoinSpendBlockedFailure(busy: busy),
        ),
      );

      final result = await _start(sender);

      expect(
        (result as core.Err).failure,
        isA<SendSpendBlockedFailure>().having((f) => f.busy, 'busy', busy),
      );
    });
  }

  test(
    'preserves the original identity of a retained directory POST',
    () async {
      final sender = _MockPayjoinSender();
      when(() => sender.start(any())).thenAnswer(
        (_) async => const Err(PayjoinSenderKeptFailure('retained-original')),
      );
      final result = await _start(sender);
      expect(
        result,
        isA<core.Err<PayjoinSenderSession, SendFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SendTransactionConfirmationFailure>().having(
            (failure) => failure.keptPayjoinOriginalTxId,
            'original identity',
            'retained-original',
          ),
        ),
      );
    },
  );

  test('sanitizes a package failure into a confirmation failure', () async {
    final sender = _MockPayjoinSender();
    when(() => sender.start(any())).thenAnswer(
      (_) async => const Err<PayjoinSenderSession, PayjoinFailure>(
        PayjoinStorageFailure(),
      ),
    );

    final result = await _start(sender);

    switch (result) {
      case core.Ok():
        fail('a failed payjoin start must not look like a started session');
      case core.Err(:final failure):
        // Confirmation, not build: the transaction exists and the user can
        // retry from the confirm screen.
        expect(failure, isA<SendTransactionConfirmationFailure>());
    }
  });
}

final class _SigningSpend extends FakeSpend {
  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async => Ok(SpendFixtures.signedBitcoin('signed-original'));
}

final class _HandoffSpend extends FakeSpend {
  PreparedBitcoinSpend? signedFrom;
  PreparedBitcoinSpend? admittedFrom;

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    signedFrom = prepared;
    return Ok(SpendFixtures.signedBitcoin('exact-signature'));
  }

  @override
  Future<Result<PayjoinSpendHandoff, SpendFailure>> handOffToPayjoin(
    PreparedBitcoinSpend prepared, {
    required WalletKey wallet,
    required String sessionId,
    required String signedPsbt,
    required Future<void> Function() persist,
  }) async {
    admittedFrom = prepared;
    expect(wallet.id, 'wallet-1');
    expect(wallet.network, BitcoinNetwork.mainnet);
    expect(sessionId, 'session');
    expect(signedPsbt, 'exact-signature');
    return const Err(SpendUnavailableFailure(busy: true));
  }
}
