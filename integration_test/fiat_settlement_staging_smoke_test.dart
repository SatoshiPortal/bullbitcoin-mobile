import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// SPEC-FIAT-STAGING-T3 - Tier 3 fiat-settlement smoke against the staging
// Bullnym (BULLNYM_BASE_URL dart-define -> https://pay2.bull-wallet.com;
// app-created, never-funded wallet; no nym registration). Mirrors
// fiat_settlement_live_nopay_test.dart and adds the fiat-capable staging cases.
//
// Three dart-define gates map to the three standing blockers:
//   FIAT_STAGING_REACHABLE=true     - a reachable staging Bullnym base URL is
//                                     configured. Enables the version-agnostic
//                                     DEGRADATION proofs, which hold on today's
//                                     pay2 (no fiat endpoints -> 404 -> the
//                                     client yields an all-Bitcoin view).
//   FIAT_STAGING_FIAT_DEPLOYED=true - the Bullnym fiat-settlement endpoints are
//                                     deployed (Bullnym #197/#198 = blocker 3).
//                                     Gates the fiat-capable assertions
//                                     (disable, credentialProblem mapping,
//                                     enable-via-key). BLOCKED until deployed.
//   FIAT_STAGING_CONTRACT=true      - the credential error-code contract is
//                                     aligned (blocker 2). Additionally gates
//                                     the enable-via-imported-key success case.
const _reachable = bool.fromEnvironment('FIAT_STAGING_REACHABLE');
const _fiatDeployed = bool.fromEnvironment('FIAT_STAGING_FIAT_DEPLOYED');
const _contract = bool.fromEnvironment('FIAT_STAGING_CONTRACT');

const _scopedKeyFilePath = String.fromEnvironment(
  'FIAT_STAGING_SCOPED_KEY_FILE',
);
final _scopedFormat = RegExp(r'^bbak-[0-9a-f]{64}$');

String? _capturedScopedKey() {
  if (_scopedKeyFilePath.isEmpty) return null;
  final f = File(_scopedKeyFilePath);
  if (!f.existsSync()) return null;
  final v = f.readAsStringSync().trim();
  return _scopedFormat.hasMatch(v) ? v : null;
}

const _blockedNoUrl =
    'BLOCKED(missing bullnym staging URL) - pass --dart-define=FIAT_STAGING_REACHABLE=true '
    'with BULLNYM_BASE_URL set';
const _blockedDeploy =
    'BLOCKED(blocker 3: Bullnym fiat endpoints undeployed on pay2) - pass '
    '--dart-define=FIAT_STAGING_FIAT_DEPLOYED=true once #197/#198 are deployed';
const _blockedContract =
    'BLOCKED(blocker 2: credential error-code mismatch, owner decision pending) - '
    'pass --dart-define=FIAT_STAGING_CONTRACT=true once aligned';

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  setUpAll(() async {
    // App-created throwaway wallet: the fiat signer needs the default wallet
    // xprv; nothing is registered server-side and the wallet is never funded.
    await locator<CreateDefaultWalletsUsecase>().execute();
  });

  Future<bool> isTestnet() async =>
      (await locator<GetSettingsUsecase>().execute()).environment.isTestnet;

  Future<void> clearScopedKey() async {
    await locator<BullbitcoinApiKeyDatasource>().deleteSellToFiatBalanceApiKey(
      isTestnet: await isTestnet(),
    );
  }

  // Never prints the value; matches on shape only.
  bool textLeaksKey(String text) => text.contains(RegExp(r'bbak-[0-9a-f]{8}'));

  // ===== Degradation group - runnable against today's pay2 (404) ==========

  test(
    'LIVE read degrades to an all-Bitcoin view on any server version',
    () async {
      final result = await locator<FiatSettlementFacade>().configuration();
      final view = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'configuration read must degrade, not fail: $failure',
        ),
      };
      for (final product in FiatSettlementProduct.values) {
        expect(view.configFor(product).isBitcoinOnly, isTrue);
      }
      expect(view.credentialActive, isFalse);
    },
    skip: _reachable ? false : _blockedNoUrl,
  );

  test('LIVE keyless activation is rejected with a typed failure and leaves no '
      'settlement state behind (no-pay safe against a 404 server)', () async {
    await clearScopedKey();
    final write = await locator<FiatSettlementFacade>().set(
      product: FiatSettlementProduct.paymentPage,
      fiatPercentage: 50,
      currency: FiatCurrency.cad,
    );
    final failure = switch (write) {
      Ok() => fail('keyless activation must not succeed for a fresh nym'),
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
    final reread = await locator<FiatSettlementFacade>().configuration();
    final view = switch (reread) {
      Ok(:final value) => value,
      Err(:final failure) => fail('re-read after rejected write: $failure'),
    };
    expect(
      view.configFor(FiatSettlementProduct.paymentPage).isBitcoinOnly,
      isTrue,
    );
  }, skip: _reachable ? false : _blockedNoUrl);

  test(
    'LIVE server never echoes a scoped key in any observable result',
    () async {
      final cfg = await locator<FiatSettlementFacade>().configuration();
      final asText = switch (cfg) {
        Ok(:final value) => value.toString(),
        Err(:final failure) => failure.toString(),
      };
      expect(textLeaksKey(asText), isFalse);
    },
    skip: _reachable ? false : _blockedNoUrl,
  );

  // ===== Fiat-capable group - needs the Bullnym fiat deploy (blocker 3) ====

  test(
    'Bitcoin-only stays intact: disable (0%) succeeds WITHOUT a scoped key',
    () async {
      await clearScopedKey();
      final result = await locator<FiatSettlementFacade>().disable(
        product: FiatSettlementProduct.pos,
      );
      final view = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('keyless disable must succeed: $failure'),
      };
      expect(view.configFor(FiatSettlementProduct.pos).isBitcoinOnly, isTrue);
    },
    skip: (_reachable && _fiatDeployed)
        ? false
        : (!_reachable ? _blockedNoUrl : _blockedDeploy),
  );

  test(
    'missing scoped key -> credentialProblem specifically (Reconnect UX)',
    () async {
      await clearScopedKey();
      final write = await locator<FiatSettlementFacade>().set(
        product: FiatSettlementProduct.paymentPage,
        fiatPercentage: 50,
        currency: FiatCurrency.cad,
      );
      final failure = switch (write) {
        Ok() => fail('activation without a scoped key must not succeed'),
        Err(:final failure) => failure,
      };
      // On a fiat-capable server the keyless PUT answers the stable credential
      // code -> credentialProblem, the type the Reconnect UX keys off of.
      expect(failure, const FiatSettlementFailure.credentialProblem());
    },
    skip: (_reachable && _fiatDeployed)
        ? false
        : (!_reachable ? _blockedNoUrl : _blockedDeploy),
  );

  test(
    'enable fiat (50% CAD) with an imported scoped key -> key-on-demand retry '
    'succeeds (validateSellToBalance observable as a successful set)',
    () async {
      final scoped = _capturedScopedKey();
      if (scoped == null) {
        fail('needs a captured scoped key handoff (Tier 1, blocker 1)');
      }
      await locator<BullbitcoinApiKeyDatasource>().storeSellToFiatBalanceApiKey(
        ScopedApiKeyModel(userId: 'staging-smoke-user', key: scoped),
        isTestnet: await isTestnet(),
      );
      final write = await locator<FiatSettlementFacade>().set(
        product: FiatSettlementProduct.paymentPage,
        fiatPercentage: 50,
        currency: FiatCurrency.cad,
      );
      final view = switch (write) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'key-on-demand activation failed: $failure',
        ),
      };
      final cfg = view.configFor(FiatSettlementProduct.paymentPage);
      expect(cfg.fiatPercentage, 50);
      expect(cfg.currency, FiatCurrency.cad);
      expect(textLeaksKey(view.toString()), isFalse);
      await clearScopedKey();
    },
    // Needs a live fiat-capable server (blocker 3) AND the aligned error-code
    // contract (blocker 2).
    skip: (_reachable && _fiatDeployed && _contract)
        ? false
        : (!_reachable
              ? _blockedNoUrl
              : (!_fiatDeployed ? _blockedDeploy : _blockedContract)),
  );

  test(
    'KYC / outage(503) fault mapping - documents which faults the staging '
    'fixture can induce',
    () async {
      // The staging VM drives a fixture-controlled provider (VM-local
      // api-orders; Liquidnode not deployed). From the mobile client we cannot
      // force a KYC-required or 503 response without server-side fixture
      // control, so this matrix is asserted deterministically in
      // fiat_settlement_lifecycle_test.dart (fake-backed) and documented here
      // as fixture-dependent for the staging lane.
    },
    skip:
        'documented as fixture-dependent; deterministic coverage lives in '
        'the fake-backed lifecycle spec',
  );
}
