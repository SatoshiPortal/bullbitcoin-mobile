import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// SPEC-FIAT-STAGING-T3 - Tier 3 fiat-settlement smoke against the staging
// Bullnym (BULLNYM_BASE_URL -> https://staging-vibe-bullnym.bull-wallet.com),
// which runs the real Bullnym fiat build (PR #197/#198) with a FIXTURE Bull
// Bitcoin provider.
//
// Identity gate: the deployed contract requires the signing npub to be a
// registered active identity for fiat reads/set/disable (require_active_identity).
// setUpAll therefore registers a throwaway wallet-owned nym (no funds, fresh
// seed per run so permanent-names are never reused).
//
// Scoped keys: the staging provider is a fixture that returns "eligible" for
// any well-formed key whose hex body does NOT start with a fault tag, and
// injects a fault for f1 (KYC) / f2 (wrong-scope) / f3 (503) / f4 (delayed).
// So these cases drive the client's key-on-demand retry + the full server
// error mapping with SYNTHETIC keys - no real Bull Bitcoin credential (and
// therefore no exchange login) is needed on staging. A real captured key
// (FIAT_STAGING_SCOPED_KEY_FILE) is preferred for the happy path when present.
//
// dart-define gates (set by the getpaid-e2e fiat-staging lane):
//   FIAT_STAGING_REACHABLE=true     - a reachable staging Bullnym is configured.
//   FIAT_STAGING_FIAT_DEPLOYED=true - the fiat endpoints are deployed.
//   FIAT_STAGING_CONTRACT=true      - the credential error-code contract is
//                                     aligned (BULL_BITCOIN_CREDENTIAL_*).
const _reachable = bool.fromEnvironment('FIAT_STAGING_REACHABLE');
const _fiatDeployed = bool.fromEnvironment('FIAT_STAGING_FIAT_DEPLOYED');
const _contract = bool.fromEnvironment('FIAT_STAGING_CONTRACT');
const _runId = String.fromEnvironment('GETPAID_FIAT_RUN_ID');

const _scopedKeyFilePath = String.fromEnvironment(
  'FIAT_STAGING_SCOPED_KEY_FILE',
);
final _scopedFormat = RegExp(r'^bbak-[0-9a-f]{64}$');

// Clearly-synthetic, well-formed scoped keys selecting fixture behaviour by the
// two hex chars after `bbak-`: 00.. = eligible, f1.. = KYC, f3.. = 503.
const _syntheticEligibleKey =
    'bbak-0000000000000000000000000000000000000000000000000000000000000000';
const _syntheticKycKey =
    'bbak-f100000000000000000000000000000000000000000000000000000000000000';
const _syntheticOutageKey =
    'bbak-f300000000000000000000000000000000000000000000000000000000000000';

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
    'BLOCKED(fiat endpoints not deployed) - pass '
    '--dart-define=FIAT_STAGING_FIAT_DEPLOYED=true once #197/#198 are deployed';
const _blockedContract =
    'BLOCKED(credential error-code contract) - pass '
    '--dart-define=FIAT_STAGING_CONTRACT=true once aligned';
// Enabling fiat / driving fixture faults requires the scoped key to be
// validated by a provider that accepts it. This staging Bullnym is configured
// against the REAL api-orders gateway (:8880), which 401s synthetic keys; the
// tag fixture (:8888, f1/f3/...) is not the wired provider. So these cases need
// either the server repointed at the fixture or a real authorized key (the
// generate-api-key/API-Users path, currently behind the login regression).
// Gated OFF by default; the deterministic enable/fault matrix is covered by the
// fake-backed integration_test/fiat_settlement_lifecycle_test.dart.
const _providerAcceptsScopedKey = bool.fromEnvironment(
  'FIAT_STAGING_PROVIDER_ACCEPTS_KEY',
);
const _blockedProvider =
    'BLOCKED(provider topology) - staging Bullnym uses the real api-orders '
    'gateway (:8880) which rejects synthetic keys; pass '
    '--dart-define=FIAT_STAGING_PROVIDER_ACCEPTS_KEY=true once the server is '
    'pointed at the tag fixture or a real authorized key is available';

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  setUpAll(() async {
    // App-created throwaway wallet (fresh seed) providing the fiat signer's
    // default-wallet xprv, then a unique registered nym so the deployed
    // identity gate admits the fiat calls. Registration needs no funds.
    await locator<CreateDefaultWalletsUsecase>().execute();
    if (_reachable && _fiatDeployed) {
      final base = 'fs${_runId.isEmpty ? 'local' : _runId}';
      final nym = base.length > 32 ? base.substring(0, 32) : base;
      await locator<LightningAddressFacade>().registerWalletOwned(nym: nym);
    }
  });

  Future<bool> isTestnet() async =>
      (await locator<GetSettingsUsecase>().execute()).environment.isTestnet;

  Future<void> clearScopedKey() async {
    await locator<BullbitcoinApiKeyDatasource>().deleteSellToFiatBalanceApiKey(
      isTestnet: await isTestnet(),
    );
  }

  Future<void> storeScopedKey(String key) async {
    await locator<BullbitcoinApiKeyDatasource>().storeSellToFiatBalanceApiKey(
      ScopedApiKeyModel(userId: 'staging-smoke-user', key: key),
      isTestnet: await isTestnet(),
    );
  }

  // Never prints the value; matches on shape only.
  bool textLeaksKey(String text) => text.contains(RegExp(r'bbak-[0-9a-f]{8}'));

  final fiatCapableSkip = (_reachable && _fiatDeployed)
      ? false
      : (!_reachable ? _blockedNoUrl : _blockedDeploy);
  final contractSkip = (_reachable && _fiatDeployed && _contract)
      ? false
      : (!_reachable
            ? _blockedNoUrl
            : (!_fiatDeployed ? _blockedDeploy : _blockedContract));
  // enable / fault cases additionally need a provider that accepts the scoped
  // key (see _blockedProvider). Gated OFF against the real gateway.
  final providerSkip =
      (_reachable && _fiatDeployed && _contract && _providerAcceptsScopedKey)
      ? false
      : (contractSkip == false ? _blockedProvider : contractSkip);

  // ===== Read / degradation group ==========================================

  test(
    'LIVE configuration read returns an all-Bitcoin view for a registered, '
    'unconfigured identity (validates the version-carrying signed GET)',
    () async {
      final result = await locator<FiatSettlementFacade>().configuration();
      final view = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'configuration read must succeed/degrade, not fail: $failure',
        ),
      };
      for (final product in FiatSettlementProduct.values) {
        expect(view.configFor(product).isBitcoinOnly, isTrue);
      }
      expect(view.credentialActive, isFalse);
    },
    skip: fiatCapableSkip,
  );

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
    skip: fiatCapableSkip,
  );

  // ===== Fiat-capable group ================================================

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
    skip: fiatCapableSkip,
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
      // Keyless PUT -> stable BULL_BITCOIN_CREDENTIAL_REQUIRED -> credentialProblem.
      expect(failure, const FiatSettlementFailure.credentialProblem());
    },
    skip: fiatCapableSkip,
  );

  // Fault cases run BEFORE the enable case: they rely on the keyless ->
  // key-on-demand-retry path (no active server credential yet), so the local
  // f1/f3 key is what the fixture validates. Once enable establishes a stored
  // credential, keyless writes succeed against it and the local key is unused.
  test(
    'fixture fault mapping: f1 -> kycRequired, f3 -> dependencyUnavailable',
    () async {
      await storeScopedKey(_syntheticKycKey);
      final kyc = await locator<FiatSettlementFacade>().set(
        product: FiatSettlementProduct.paymentPage,
        fiatPercentage: 50,
        currency: FiatCurrency.cad,
      );
      expect((kyc as Err).failure, const FiatSettlementFailure.kycRequired());

      await storeScopedKey(_syntheticOutageKey);
      final outage = await locator<FiatSettlementFacade>().set(
        product: FiatSettlementProduct.paymentPage,
        fiatPercentage: 50,
        currency: FiatCurrency.cad,
      );
      expect(
        (outage as Err).failure,
        const FiatSettlementFailure.dependencyUnavailable(),
      );
      await clearScopedKey();
    },
    skip: providerSkip,
  );

  // Runs LAST: establishes an active server-side credential (retained after
  // disable), which would mask the keyless->retry path the fault cases need.
  test(
    'enable fiat (50% CAD) with a scoped key -> key-on-demand retry succeeds '
    '(fixture validates the key as eligible)',
    () async {
      // Prefer a real captured key if a handoff exists; otherwise a synthetic
      // eligible key, which the staging fixture accepts.
      final key = _capturedScopedKey() ?? _syntheticEligibleKey;
      await storeScopedKey(key);
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
      // Return the product to Bitcoin-only so the run leaves no fiat config.
      await locator<FiatSettlementFacade>().disable(
        product: FiatSettlementProduct.paymentPage,
      );
      await clearScopedKey();
    },
    skip: providerSkip,
  );
}
