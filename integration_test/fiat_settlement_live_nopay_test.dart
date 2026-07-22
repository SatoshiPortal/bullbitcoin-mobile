import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// SPEC-FIAT-02 - LIVE no-pay fiat-settlement probes against a real Bullnym
// server (BULLNYM_BASE_URL dart-define; the getpaid-e2e fiat-nopay lane
// provides it).
//
// No-pay guarantees: an app-created throwaway wallet that is never funded, no
// invoice, and no send/broadcast surface anywhere in the import graph. The
// fiat-capable lane registers one fresh wallet-owned nym because Bullnym
// requires an active identity before returning private configuration. Other
// server writes are limited to fiat-settlement PUTs that are EXPECTED to be
// rejected (no scoped credential exists), so no settlement state is created.
//
// The live probes are explicitly armed with
// GETPAID_FIAT_CONTRACT_LIVE=true. The configured server must expose the fiat
// routes and accept registration of the fresh wallet-owned identity used by
// this test. A keyless PUT must answer
// the stable FIAT_CREDENTIAL_REQUIRED code (which also proves the signed
// bullpay-la-v2 request verified server-side; a broken signature would fail
// auth, mapping to a different failure).
const _contractLive = bool.fromEnvironment('GETPAID_FIAT_CONTRACT_LIVE');
const _runId = String.fromEnvironment('GETPAID_FIAT_RUN_ID');

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  setUpAll(() async {
    // App-created throwaway wallet: the fiat signer needs the default wallet
    // xprv. A live fiat server requires this npub to own an active identity,
    // so register a unique nym only for the explicitly armed contract lane.
    await locator<CreateDefaultWalletsUsecase>().execute();
    if (_contractLive) {
      final suffix = _runId.isEmpty
          ? DateTime.now().toUtc().millisecondsSinceEpoch.toString()
          : _runId;
      final base = 'fsnp$suffix';
      final nym = base.length > 32 ? base.substring(0, 32) : base;
      await locator<LightningAddressFacade>().registerWalletOwned(nym: nym);
    }
  });

  test('LIVE configuration read yields an all-Bitcoin view for a fresh '
      'identity', () async {
    final result = await locator<FiatSettlementFacade>().configuration();
    final view = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail(
        'configuration read must degrade, not fail: $failure',
      ),
    };
    for (final product in FiatSettlementProduct.values) {
      expect(
        view.configFor(product).isBitcoinOnly,
        isTrue,
        reason: 'fresh identity / old server must read as Bitcoin-only',
      );
    }
    expect(view.credentialActive, isFalse);
  }, skip: _contractLive ? false : 'needs an explicitly armed fiat server');

  test('LIVE keyless activation attempt is rejected with a typed failure and '
      'leaves no settlement state behind', () async {
    final facade = locator<FiatSettlementFacade>();
    final write = await facade.set(
      product: FiatSettlementProduct.paymentPage,
      fiatPercentage: 50,
      currency: FiatCurrency.cad,
    );
    // No scoped credential exists for this fresh identity, so success is
    // impossible on ANY correct server; the failure must be one of the closed
    // family's server-outcome members (never a crash, never invalidInput -
    // the request itself is well-formed).
    final failure = switch (write) {
      Ok() => fail('keyless activation must never succeed for a fresh nym'),
      Err(:final failure) => failure,
    };
    expect(
      failure,
      anyOf(
        const FiatSettlementFailure.credentialProblem(),
        const FiatSettlementFailure.kycRequired(),
        const FiatSettlementFailure.dependencyUnavailable(),
        const FiatSettlementFailure.bullnymUnreachable(),
        const FiatSettlementFailure.unexpected(),
      ),
    );

    // The rejected write must not have created partial server state.
    final reread = await facade.configuration();
    final view = switch (reread) {
      Ok(:final value) => value,
      Err(:final failure) => fail(
        're-read after rejected write failed: $failure',
      ),
    };
    expect(
      view.configFor(FiatSettlementProduct.paymentPage).isBitcoinOnly,
      isTrue,
    );
  }, skip: _contractLive ? false : 'needs an explicitly armed fiat server');

  test(
    'LIVE #196 contract: keyless PUT answers the stable '
    'FIAT_CREDENTIAL_REQUIRED code (signed request verified)',
    () async {
      final write = await locator<FiatSettlementFacade>().set(
        product: FiatSettlementProduct.pos,
        fiatPercentage: 100,
        currency: FiatCurrency.usd,
      );
      final failure = switch (write) {
        Ok() => fail('keyless activation must never succeed for a fresh nym'),
        Err(:final failure) => failure,
      };
      // credentialProblem is reachable ONLY via FIAT_CREDENTIAL_REQUIRED /
      // FIAT_CREDENTIAL_INVALID - i.e. the server understood and authenticated
      // the signed fiat-settlement request and applied the #196 contract.
      expect(failure, const FiatSettlementFailure.credentialProblem());
    },
    skip: _contractLive
        ? false
        : 'needs a BullishNode/bullnym#196 server '
              '(pass --dart-define=GETPAID_FIAT_CONTRACT_LIVE=true)',
  );
}
