import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/entities/fiat_settlement.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/scoped_settlement_key_port.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/set_fiat_settlement_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBullnymFacade extends Mock implements BullnymFacade {}

class _MockXprvPort extends Mock
    implements FiatSettlementDefaultWalletXprvPort {}

class _MockNostrIdentity extends Mock implements NostrIdentityFacade {}

class _MockScopedKeyPort extends Mock implements ScopedSettlementKeyPort {}

const _scopedKey =
    'bbak-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _npubHex =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

const _okConfig = BullnymFiatSettlementConfiguration(
  settings: [],
  credentialStatus: BullnymCredentialStatus.active,
);

const _credentialRequired = BullnymFailure.serverRejectedRequest(
  code: 'FIAT_CREDENTIAL_REQUIRED',
  logMessage: 'no stored credential',
  retryable: false,
);

void main() {
  late _MockBullnymFacade bullnym;
  late _MockXprvPort xprvPort;
  late _MockNostrIdentity nostrIdentity;
  late _MockScopedKeyPort scopedKey;
  late SetFiatSettlementUsecase usecase;

  setUpAll(() {
    registerFallbackValue(BullnymFiatSettlementProduct.invoice);
    registerFallbackValue(
      BullnymAuthSigner(npubHex: _npubHex, signHashHex: (_) => '11' * 64),
    );
  });

  setUp(() {
    bullnym = _MockBullnymFacade();
    xprvPort = _MockXprvPort();
    nostrIdentity = _MockNostrIdentity();
    scopedKey = _MockScopedKeyPort();
    usecase = SetFiatSettlementUsecase(
      bullnym: bullnym,
      xprvPort: xprvPort,
      nostrIdentity: nostrIdentity,
      scopedKey: scopedKey,
    );

    when(
      () => xprvPort.deriveDefaultWalletXprv(),
    ).thenAnswer((_) async => 'xprv');
    when(
      () => nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(any()),
    ).thenReturn(_npubHex);
    when(
      () => nostrIdentity.signBullnymServerAuthHashFromXprv(
        xprvBase58: any(named: 'xprvBase58'),
        messageHashHex: any(named: 'messageHashHex'),
      ),
    ).thenReturn('11' * 64);
  });

  void stubSet({
    required Result<BullnymFiatSettlementConfiguration, BullnymFailure>
    withoutKey,
    Result<BullnymFiatSettlementConfiguration, BullnymFailure>? withKey,
  }) {
    when(
      () => bullnym.setFiatSettlement(
        signer: any(named: 'signer'),
        product: any(named: 'product'),
        fiatPercentage: any(named: 'fiatPercentage'),
        fiatCurrency: any(named: 'fiatCurrency'),
        apiKey: any(named: 'apiKey'),
      ),
    ).thenAnswer((invocation) async {
      final apiKey = invocation.namedArguments[#apiKey] as String?;
      if (apiKey == null) return withoutKey;
      return withKey ?? const Err(BullnymFailure.unexpected());
    });
  }

  test('normal edit succeeds without any key read or transmission', () async {
    stubSet(withoutKey: const Ok(_okConfig));

    final result = await usecase.execute(
      product: FiatSettlementProduct.paymentPage,
      fiatPercentage: 50,
      currency: FiatCurrency.cad,
    );

    expect(result, isA<Ok>());
    verifyNever(() => scopedKey.readPlaintext());
    final captured = verify(
      () => bullnym.setFiatSettlement(
        signer: any(named: 'signer'),
        product: BullnymFiatSettlementProduct.paymentPage,
        fiatPercentage: 50,
        fiatCurrency: 'CAD',
        apiKey: captureAny(named: 'apiKey'),
      ),
    ).captured;
    expect(captured.single, isNull);
  });

  test(
    'FIAT_CREDENTIAL_REQUIRED triggers exactly one retry with the local key',
    () async {
      stubSet(
        withoutKey: const Err(_credentialRequired),
        withKey: const Ok(_okConfig),
      );
      when(() => scopedKey.readPlaintext()).thenAnswer((_) async => _scopedKey);

      final result = await usecase.execute(
        product: FiatSettlementProduct.invoice,
        fiatPercentage: 100,
        currency: FiatCurrency.usd,
      );

      expect(result, isA<Ok>());
      verify(() => scopedKey.readPlaintext()).called(1);
      final capturedKeys = verify(
        () => bullnym.setFiatSettlement(
          signer: any(named: 'signer'),
          product: BullnymFiatSettlementProduct.invoice,
          fiatPercentage: 100,
          fiatCurrency: 'USD',
          apiKey: captureAny(named: 'apiKey'),
        ),
      ).captured;
      expect(capturedKeys, [null, _scopedKey]);
    },
  );

  test(
    'credential required with no local key maps to credentialProblem',
    () async {
      stubSet(withoutKey: const Err(_credentialRequired));
      when(() => scopedKey.readPlaintext()).thenAnswer((_) async => null);

      final result = await usecase.execute(
        product: FiatSettlementProduct.invoice,
        fiatPercentage: 100,
        currency: FiatCurrency.usd,
      );

      expect(
        (result as Err).failure,
        isA<FiatSettlementCredentialProblemFailure>(),
      );
      // Only the optimistic attempt went out; no key was transmitted.
      verify(
        () => bullnym.setFiatSettlement(
          signer: any(named: 'signer'),
          product: any(named: 'product'),
          fiatPercentage: any(named: 'fiatPercentage'),
          fiatCurrency: any(named: 'fiatCurrency'),
          apiKey: null,
        ),
      ).called(1);
    },
  );

  test(
    'a rejected retry key (FIAT_CREDENTIAL_INVALID) maps to credentialProblem '
    'and never loops',
    () async {
      stubSet(
        withoutKey: const Err(_credentialRequired),
        withKey: const Err(
          BullnymFailure.serverRejectedRequest(
            code: 'FIAT_CREDENTIAL_INVALID',
            logMessage: 'revoked',
            retryable: false,
          ),
        ),
      );
      when(() => scopedKey.readPlaintext()).thenAnswer((_) async => _scopedKey);

      final result = await usecase.execute(
        product: FiatSettlementProduct.pos,
        fiatPercentage: 25,
        currency: FiatCurrency.eur,
      );

      expect(
        (result as Err).failure,
        isA<FiatSettlementCredentialProblemFailure>(),
      );
      verify(() => scopedKey.readPlaintext()).called(1);
    },
  );

  test('non-credential failures never trigger a key read or retry', () async {
    stubSet(
      withoutKey: const Err(
        BullnymFailure.serverRejectedRequest(
          code: 'FIAT_CONVERSION_KYC_REQUIRED',
          logMessage: 'kyc',
          retryable: false,
        ),
      ),
    );

    final result = await usecase.execute(
      product: FiatSettlementProduct.invoice,
      fiatPercentage: 100,
      currency: FiatCurrency.usd,
    );

    expect((result as Err).failure, isA<FiatSettlementKycRequiredFailure>());
    verifyNever(() => scopedKey.readPlaintext());
  });

  test('rejects an out-of-range percentage before any work', () async {
    final result = await usecase.execute(
      product: FiatSettlementProduct.pos,
      fiatPercentage: 0,
      currency: FiatCurrency.cad,
    );
    expect((result as Err).failure, isA<FiatSettlementInvalidInputFailure>());
    verifyNever(() => xprvPort.deriveDefaultWalletXprv());
  });
}
