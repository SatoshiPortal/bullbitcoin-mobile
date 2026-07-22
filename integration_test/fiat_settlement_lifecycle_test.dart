import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fake_bullnym_client.dart';
import 'support/get_paid_fixtures.dart';

// SPEC-FIAT-01 - the fake-backed Bull Bitcoin fiat-settlement lifecycle.
//
// AUTHORED-BUT-CI-ONLY (same rationale as payment_page_lifecycle_test.dart):
// runs the REAL app stack (Bull.init locator graph, default-wallet xprv
// signer, facade -> usecases -> BullnymFacade) against the in-memory
// FakeBullnymClient, swapped in at the BullnymClientPort seam. It proves the
// full DI wiring plus the issue #196 optimistic-save / key-on-demand contract
// end-to-end in-process:
//   - set/get/disable round-trip with server-confirmed configuration,
//   - first attempt is ALWAYS keyless; the scoped key is transmitted at most
//     once, only after FIAT_CREDENTIAL_REQUIRED, and only when present,
//   - stable error codes map to the closed failure family (KYC / credential /
//     dependency-503), with the exact action-set-relevant distinctions,
//   - an old server (404 surface) degrades to an empty Bitcoin-only view on
//     read and a typed failure on write - never a crash.
// The signed BYTE contract (NUL-joined bullpay-la-v2 vectors, 0% omission) is
// pinned separately by test/features/bullnym/bullnym_fiat_settlement_contract_test.dart.

const _scopedKeyPlaintext =
    // Well-formed test-only value (bbak- + 64 hex); never a real credential.
    'bbak-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  late FakeBullnymClient bullnym;

  setUpAll(() async {
    bullnym = FakeBullnymClient();
    await locator.unregister<BullnymClientPort>();
    locator.registerLazySingleton<BullnymClientPort>(() => bullnym);
    await locator<CreateDefaultWalletsUsecase>().execute(
      mnemonicWords: getPaidFixtureMnemonicWords,
    );
  });

  setUp(() {
    bullnym.fiatSettlementMode = FakeFiatSettlementMode.normal;
    bullnym.setFiatSettlementCalls.clear();
  });

  Future<void> clearScopedKey() async {
    final settings = await locator<GetSettingsUsecase>().execute();
    await locator<BullbitcoinApiKeyDatasource>().deleteSellToFiatBalanceApiKey(
      isTestnet: settings.environment.isTestnet,
    );
  }

  Future<void> storeScopedKey() async {
    final settings = await locator<GetSettingsUsecase>().execute();
    await locator<BullbitcoinApiKeyDatasource>().storeSellToFiatBalanceApiKey(
      const ScopedApiKeyModel(userId: 'qa-user', key: _scopedKeyPlaintext),
      isTestnet: settings.environment.isTestnet,
    );
  }

  test('set -> get -> disable round-trip; edits with an active server '
      'credential transmit the scoped key zero times', () async {
    bullnym.fiatCredentialStatus = BullnymCredentialStatus.active;
    await clearScopedKey();

    final facade = locator<FiatSettlementFacade>();
    final set = await facade.set(
      product: FiatSettlementProduct.paymentPage,
      fiatPercentage: 50,
      currency: FiatCurrency.cad,
    );
    final afterSet = switch (set) {
      Ok(:final value) => value,
      Err(:final failure) => fail('set failed: $failure'),
    };
    final config = afterSet.configFor(FiatSettlementProduct.paymentPage);
    expect(config.mode, FiatSettlementMode.mixed);
    expect(config.fiatPercentage, 50);
    expect(config.currency, FiatCurrency.cad);

    // Exactly one PUT, keyless: the server credential is the source of truth.
    expect(bullnym.setFiatSettlementCalls, hasLength(1));
    expect(bullnym.setFiatSettlementCalls.single.apiKey, isNull);
    expect(bullnym.setFiatSettlementCalls.single.fiatCurrency, 'CAD');

    final read = await facade.configuration();
    final view = switch (read) {
      Ok(:final value) => value,
      Err(:final failure) => fail('configuration failed: $failure'),
    };
    expect(
      view.configFor(FiatSettlementProduct.paymentPage).fiatPercentage,
      50,
    );
    // Untouched products stay Bitcoin-only.
    expect(view.configFor(FiatSettlementProduct.pos).isBitcoinOnly, isTrue);

    final disabled = await facade.disable(
      product: FiatSettlementProduct.paymentPage,
    );
    final afterDisable = switch (disabled) {
      Ok(:final value) => value,
      Err(:final failure) => fail('disable failed: $failure'),
    };
    expect(
      afterDisable.configFor(FiatSettlementProduct.paymentPage).isBitcoinOnly,
      isTrue,
    );
    // Disable is a keyless 0% PUT; the server credential is retained.
    expect(bullnym.setFiatSettlementCalls.last.fiatPercentage, 0);
    expect(bullnym.setFiatSettlementCalls.last.apiKey, isNull);
    expect(bullnym.fiatCredentialStatus, BullnymCredentialStatus.active);
  });

  test('key-on-demand: FIAT_CREDENTIAL_REQUIRED triggers exactly one retry '
      'carrying the locally stored scoped key', () async {
    bullnym.fiatSettlementMode = FakeFiatSettlementMode.credentialRequired;
    bullnym.fiatCredentialStatus = BullnymCredentialStatus.absent;
    await storeScopedKey();

    final result = await locator<FiatSettlementFacade>().set(
      product: FiatSettlementProduct.pos,
      fiatPercentage: 100,
      currency: FiatCurrency.usd,
    );
    final view = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('set failed: $failure'),
    };
    expect(
      view.configFor(FiatSettlementProduct.pos).mode,
      FiatSettlementMode.fiatOnly,
    );

    // The wire order IS the contract: keyless first, keyed retry second,
    // nothing after.
    expect(bullnym.setFiatSettlementCalls, hasLength(2));
    expect(bullnym.setFiatSettlementCalls[0].apiKey, isNull);
    expect(bullnym.setFiatSettlementCalls[1].apiKey, _scopedKeyPlaintext);
    expect(bullnym.fiatCredentialStatus, BullnymCredentialStatus.active);

    await clearScopedKey();
  });

  test('no local key on FIAT_CREDENTIAL_REQUIRED -> credentialProblem with '
      'no blind keyless retry', () async {
    bullnym.fiatSettlementMode = FakeFiatSettlementMode.credentialRequired;
    bullnym.fiatCredentialStatus = BullnymCredentialStatus.absent;
    await clearScopedKey();

    final result = await locator<FiatSettlementFacade>().set(
      product: FiatSettlementProduct.lightningAddress,
      fiatPercentage: 25,
      currency: FiatCurrency.crc,
    );
    expect(result, isA<Err<dynamic, dynamic>>());
    expect(
      (result as Err).failure,
      const FiatSettlementFailure.credentialProblem(),
    );
    expect(bullnym.setFiatSettlementCalls, hasLength(1));
  });

  test('rejected key (FIAT_CREDENTIAL_INVALID) -> credentialProblem after '
      'exactly one keyed retry', () async {
    bullnym.fiatSettlementMode = FakeFiatSettlementMode.credentialInvalid;
    await storeScopedKey();

    final result = await locator<FiatSettlementFacade>().set(
      product: FiatSettlementProduct.invoice,
      fiatPercentage: 10,
      currency: FiatCurrency.eur,
    );
    expect(
      (result as Err).failure,
      const FiatSettlementFailure.credentialProblem(),
    );
    expect(bullnym.setFiatSettlementCalls, hasLength(2));
    expect(bullnym.setFiatSettlementCalls[1].apiKey, _scopedKeyPlaintext);

    await clearScopedKey();
  });

  test('stable code mapping: KYC and dependency-503 map to their exact '
      'failures (distinct action sets)', () async {
    final facade = locator<FiatSettlementFacade>();

    bullnym.fiatSettlementMode = FakeFiatSettlementMode.kycRequired;
    final kyc = await facade.set(
      product: FiatSettlementProduct.paymentPage,
      fiatPercentage: 50,
      currency: FiatCurrency.cad,
    );
    expect((kyc as Err).failure, const FiatSettlementFailure.kycRequired());

    bullnym.fiatSettlementMode = FakeFiatSettlementMode.dependencyUnavailable;
    final dep = await facade.set(
      product: FiatSettlementProduct.paymentPage,
      fiatPercentage: 50,
      currency: FiatCurrency.cad,
    );
    expect(
      (dep as Err).failure,
      const FiatSettlementFailure.dependencyUnavailable(),
    );
  });

  test('old server without fiat endpoints: read degrades to an all-Bitcoin '
      'view, write surfaces a typed failure - never a crash', () async {
    bullnym.fiatSettlementMode = FakeFiatSettlementMode.unsupported;
    final facade = locator<FiatSettlementFacade>();

    final read = await facade.configuration();
    final view = switch (read) {
      Ok(:final value) => value,
      Err(:final failure) => fail('degraded read failed: $failure'),
    };
    for (final product in FiatSettlementProduct.values) {
      expect(view.configFor(product).isBitcoinOnly, isTrue);
    }
    expect(view.credentialActive, isFalse);

    final write = await facade.set(
      product: FiatSettlementProduct.pos,
      fiatPercentage: 50,
      currency: FiatCurrency.cad,
    );
    expect((write as Err).failure, const FiatSettlementFailure.unexpected());
  });
}
