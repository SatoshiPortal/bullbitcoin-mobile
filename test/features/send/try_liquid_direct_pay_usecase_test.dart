import 'package:bb_mobile/features/send/domain/entities/bullpay_proof.dart';
import 'package:bb_mobile/features/send/domain/errors/bullpay_proof_error.dart';
import 'package:bb_mobile/features/send/domain/ports/liquid_direct_pay_port.dart';
import 'package:bb_mobile/features/send/domain/usecases/build_bullpay_proof_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/try_liquid_direct_pay_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuildProof extends Mock implements BuildBullpayProofUsecase {}

class _MockLiquidDirectPay extends Mock implements LiquidDirectPayPort {}

final _proof = BullpayProof(
  outpoint: '${'aa' * 32}:0',
  pubkeyHex: 'bb' * 33,
  sigDerHex: 'cc' * 64,
  valueSat: BigInt.from(1500),
  valueBfHex: 'c0ffee',
  assetIdHex: 'dd' * 32,
  assetBfHex: 'facade',
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://bullpay.ca/cb'));
    registerFallbackValue(<String, String>{});
  });

  late _MockBuildProof buildProof;
  late _MockLiquidDirectPay liquidDirectPay;
  late TryLiquidDirectPayUsecase usecase;

  void stubProof() {
    when(
      () => buildProof.execute(
        walletId: any(named: 'walletId'),
        nym: any(named: 'nym'),
      ),
    ).thenAnswer((_) async => _proof);
  }

  void stubMetadata({
    List<String> paymentMethods = const ['L-BTC'],
    Uri? callback,
  }) {
    when(() => liquidDirectPay.fetchMetadata(any())).thenAnswer(
      (_) async => LiquidDirectPayMetadata(
        paymentMethods: paymentMethods,
        callback: callback ?? Uri.parse('https://bullpay.ca/cb'),
      ),
    );
  }

  List<Uri> stubCallback({
    LiquidDirectPayCallbackResult result = const LiquidDirectPayCallbackResult(
      liquidAddress: 'lq1qfake',
    ),
  }) {
    final calls = <Uri>[];
    when(
      () => liquidDirectPay.requestLiquidPayment(
        any(),
        query: any(named: 'query'),
      ),
    ).thenAnswer((inv) async {
      calls.add(inv.positionalArguments[0] as Uri);
      return result;
    });
    return calls;
  }

  setUp(() {
    buildProof = _MockBuildProof();
    liquidDirectPay = _MockLiquidDirectPay();
    usecase = TryLiquidDirectPayUsecase(
      buildProof: buildProof,
      liquidDirectPay: liquidDirectPay,
    );
    stubProof();
  });

  group('username/domain validation', () {
    final cases = <String>[
      'alice@evil.com/x',
      '../etc/passwd@bullpay.ca',
      'alice@bullpay.ca:8080',
      'alice@127.0.0.1',
      'alice@localhost',
      'alice@',
      '@bullpay.ca',
      'alice with space@bullpay.ca',
      'alice@bullpay',
    ];

    for (final input in cases) {
      test('rejects "$input"', () async {
        await expectLater(
          usecase.execute(lnAddress: input, amountSat: 1000, walletId: 'w'),
          throwsA(isA<LiquidDirectPayUnavailable>()),
        );
        verifyNever(() => liquidDirectPay.fetchMetadata(any()));
      });
    }

    test('accepts well-formed lowercase nym + hostname', () async {
      stubMetadata();
      stubCallback();
      final out = await usecase.execute(
        lnAddress: 'alice@bullpay.ca',
        amountSat: 1000,
        walletId: 'w',
      );
      expect(out, 'lq1qfake');
      final captured =
          verify(
                () => liquidDirectPay.fetchMetadata(captureAny()),
              ).captured.single
              as Uri;
      expect(captured.toString(), 'https://bullpay.ca/.well-known/lnurlp/alice');
    });
  });

  group('callback URL pinning (SSRF)', () {
    final invalidCallbacks = <String>[
      'http://bullpay.ca/cb',
      'https://attacker.example/cb',
      'https://bullpay.ca.attacker.example/cb',
      'javascript:alert(1)',
      '//bullpay.ca/cb',
      '',
    ];

    for (final cb in invalidCallbacks) {
      test('rejects callback "$cb" before building the proof', () async {
        stubMetadata(callback: Uri.parse(cb));
        await expectLater(
          usecase.execute(
            lnAddress: 'alice@bullpay.ca',
            amountSat: 1000,
            walletId: 'w',
          ),
          throwsA(isA<LiquidDirectPayUnavailable>()),
        );
        verifyNever(
          () => buildProof.execute(
            walletId: any(named: 'walletId'),
            nym: any(named: 'nym'),
          ),
        );
      });
    }
  });

  group('liquid direct pay', () {
    test('payment_methods without L-BTC throws Unavailable', () async {
      stubMetadata(paymentMethods: const ['BTC']);
      await expectLater(
        usecase.execute(
          lnAddress: 'alice@bullpay.ca',
          amountSat: 1000,
          walletId: 'w',
        ),
        throwsA(isA<LiquidDirectPayUnavailable>()),
      );
    });

    test('sends the Approach-B payload + msats as query params', () async {
      stubMetadata();
      stubCallback();

      await usecase.execute(
        lnAddress: 'alice@bullpay.ca',
        amountSat: 5000,
        walletId: 'w',
      );

      final capturedQuery =
          verify(
                () => liquidDirectPay.requestLiquidPayment(
                  any(),
                  query: captureAny(named: 'query'),
                ),
              ).captured.single
              as Map<String, String>;
      expect(capturedQuery, {
        'amount': '5000000',
        'payment_method': 'L-BTC',
        'outpoint': _proof.outpoint,
        'pubkey': _proof.pubkeyHex,
        'sig': _proof.sigDerHex,
        'value': '1500',
        'value_bf': 'c0ffee',
        'asset': _proof.assetIdHex,
        'asset_bf': 'facade',
      });
      // No blinding key is ever present on the wire.
      expect(capturedQuery.containsKey('blinding_key'), isFalse);
    });

    test('server ERROR with code maps to BullpayProofError', () async {
      stubMetadata();
      stubCallback(
        result: const LiquidDirectPayCallbackResult(
          status: 'ERROR',
          code: 'UtxoSpent',
          reason: 'spent',
        ),
      );

      await expectLater(
        usecase.execute(
          lnAddress: 'alice@bullpay.ca',
          amountSat: 1000,
          walletId: 'w',
        ),
        throwsA(isA<BullpayProofUtxoSpent>()),
      );
    });

    test('ProofOfFundsInvalid maps to BullpayProofInvalid', () async {
      stubMetadata();
      stubCallback(
        result: const LiquidDirectPayCallbackResult(
          status: 'ERROR',
          code: 'ProofOfFundsInvalid',
          reason: 'asset mismatch',
        ),
      );

      await expectLater(
        usecase.execute(
          lnAddress: 'alice@bullpay.ca',
          amountSat: 1000,
          walletId: 'w',
        ),
        throwsA(isA<BullpayProofInvalid>()),
      );
    });

    test('a bolt11 soft-limit response is declined (Unavailable, not paid)', () async {
      stubMetadata();
      stubCallback(
        result: const LiquidDirectPayCallbackResult(bolt11: 'lnbc10u1pexample'),
      );

      await expectLater(
        usecase.execute(
          lnAddress: 'alice@bullpay.ca',
          amountSat: 1000,
          walletId: 'w',
        ),
        throwsA(isA<LiquidDirectPayUnavailable>()),
      );
    });

    test('a response with no address and no error falls back gracefully', () async {
      stubMetadata();
      stubCallback(result: const LiquidDirectPayCallbackResult());

      await expectLater(
        usecase.execute(
          lnAddress: 'alice@bullpay.ca',
          amountSat: 1000,
          walletId: 'w',
        ),
        throwsA(isA<LiquidDirectPayUnavailable>()),
      );
    });
  });
}
