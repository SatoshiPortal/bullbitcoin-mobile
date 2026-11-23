import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

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
  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async => Ok(SpendFixtures.signedBitcoin('signed-original'));
}
