import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:bull_exchange/src/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletKey;

class _MockPayjoinSender extends Mock implements PayjoinSender {}

void main() {
  setUpAll(() {
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

  Future<Result<PayjoinSenderSession, PayFailure>> start(
    PayjoinSender sender,
  ) => SendWithPayjoinUsecase(sender, _SigningSpend()).execute(
    walletId: 'wallet-1',
    network: BitcoinNetwork.mainnet,
    bip21: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
    prepared: SpendFixtures.preparedBitcoin(
      unsignedPsbt: 'cHNidP8=',
      fee: Sats.zero,
    ),
    amountSat: 100000,
    networkFeesSatPerVb: 2,
  );

  test('a kept session after a failed post is reported as such', () async {
    final sender = _MockPayjoinSender();
    when(() => sender.start(any())).thenAnswer(
      (_) async => const Err<PayjoinSenderSession, PayjoinFailure>(
        PayjoinSenderKeptFailure(
          'sender-orig-txid',
          'Sender start failed; session kept',
        ),
      ),
    );

    final result = await start(sender);

    expect(
      (result as Err<PayjoinSenderSession, PayFailure>).failure,
      isA<PayPayjoinSessionKeptFailure>(),
    );
  });

  test(
    'an uncertain POST is not a definitely failed retained session',
    () async {
      final sender = _MockPayjoinSender();
      when(() => sender.start(any())).thenAnswer(
        (_) async => const Err(PayjoinPublicationUnknownFailure('original')),
      );
      final result = await start(sender);
      expect(
        (result as Err<PayjoinSenderSession, PayFailure>).failure,
        isA<PayPayinOutcomeUnknownFailure>().having(
          (failure) => failure.originalTxId,
          'original',
          'original',
        ),
      );
    },
  );

  test(
    'Payjoin admits the reviewed original through Spend before posting',
    () async {
      final sender = _MockPayjoinSender();
      final spend = _SigningSpend();
      final prepared = SpendFixtures.preparedBitcoin(
        unsignedPsbt: 'cHNidP8=',
        fee: Sats.zero,
      );
      var persisted = false;
      when(() => sender.start(any())).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.single as StartPayjoinSender;
        expect(request.unsignedOriginalPsbt, prepared.unsignedPsbt);
        final original = request.preparedOriginal;
        if (original == null) fail('The payin must admit its signed original');
        expect(original.signedPsbt, 'signed-original');
        final admission = await original.admit(
          sessionId: 'sender-session',
          persist: () async => persisted = true,
        );
        expect(admission, isA<Err<void, PayjoinFailure>>());
        return const Err(PayjoinSpendBlockedFailure(busy: true));
      });

      final result = await SendWithPayjoinUsecase(sender, spend).execute(
        walletId: 'wallet-1',
        network: BitcoinNetwork.mainnet,
        bip21: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
        prepared: prepared,
        amountSat: 100000,
        networkFeesSatPerVb: 2,
      );

      expect(
        (result as Err<PayjoinSenderSession, PayFailure>).failure,
        isA<PaySpendBlockedFailure>().having((f) => f.busy, 'busy', isTrue),
      );
      expect(spend.admitted, same(prepared));
      expect(
        spend.wallet,
        WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
      );
      expect(spend.sessionId, 'sender-session');
      expect(persisted, isFalse);
      verify(() => sender.start(any())).called(1);
    },
  );

  for (final busy in [true, false]) {
    test('a blocked spend keeps its busy flag (busy=$busy)', () async {
      final sender = _MockPayjoinSender();
      when(() => sender.start(any())).thenAnswer(
        (_) async => Err<PayjoinSenderSession, PayjoinFailure>(
          PayjoinSpendBlockedFailure(busy: busy),
        ),
      );

      final result = await start(sender);

      expect(
        (result as Err<PayjoinSenderSession, PayFailure>).failure,
        isA<PaySpendBlockedFailure>().having((f) => f.busy, 'busy', busy),
      );
    });
  }

  test('sanitizes any other package failure', () async {
    final sender = _MockPayjoinSender();
    when(() => sender.start(any())).thenAnswer(
      (_) async => const Err<PayjoinSenderSession, PayjoinFailure>(
        PayjoinStorageFailure(),
      ),
    );

    final result = await start(sender);

    final failure = (result as Err<PayjoinSenderSession, PayFailure>).failure;
    expect(failure, isA<PayUnexpectedFailure>());
    expect(failure, isNot(isA<PayjoinFailure>()));
  });
}

final class _SigningSpend extends FakeSpend {
  PreparedBitcoinSpend? admitted;
  WalletKey? wallet;
  String? sessionId;

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async => Ok(SpendFixtures.signedBitcoin('signed-original'));

  @override
  Future<Result<PayjoinSpendHandoff, SpendFailure>> handOffToPayjoin(
    PreparedBitcoinSpend prepared, {
    required WalletKey wallet,
    required String sessionId,
    required String signedPsbt,
    required Future<void> Function() persist,
  }) async {
    admitted = prepared;
    this.wallet = wallet;
    this.sessionId = sessionId;
    expect(signedPsbt, 'signed-original');
    return const Err(SpendUnavailableFailure(busy: true));
  }
}
