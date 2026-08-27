import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class MockSaveUserPreferencesUsecase extends Mock
    implements SaveUserPreferencesUsecase {}

class FakeWallet extends Fake implements Wallet {
  @override
  String get id => 'default-wallet';
}

/// Routed through the failing address-generation path so the test output can
/// be searched for it: it must never appear in a log line.
const _sentinelWalletId = 'wallet-id-must-not-be-logged';

/// Stands in for whatever a foreign exception message may embed — a
/// credential, a response body. It must never reach a [DcaFailure].
const _sentinelSecret = 'super-secret';

void main() {
  setUpAll(() {
    registerFallbackValue(FiatCurrency.cad);
    registerFallbackValue(DcaBuyFrequency.daily);
    registerFallbackValue(DcaNetwork.bitcoin);
  });

  late MockExchangeOrderRepository mainnetOrders;
  late MockExchangeOrderRepository testnetOrders;
  late MockWalletRepository wallet;
  late MockSettingsRepository settings;
  late MockWalletAddressRepository walletAddress;
  late MockSaveUserPreferencesUsecase savePreferences;
  late SetDcaUsecase usecase;

  const mainnetSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  final dca = Dca(
    amount: 10,
    currency: FiatCurrency.cad,
    frequency: DcaBuyFrequency.daily,
    network: DcaNetwork.lightning,
    address: 'user@lightning.address',
    nextPurchaseDate: DateTime(2026),
  );

  setUp(() {
    mainnetOrders = MockExchangeOrderRepository();
    testnetOrders = MockExchangeOrderRepository();
    wallet = MockWalletRepository();
    settings = MockSettingsRepository();
    walletAddress = MockWalletAddressRepository();
    savePreferences = MockSaveUserPreferencesUsecase();
    usecase = SetDcaUsecase(
      mainnetExchangeOrderRepository: mainnetOrders,
      testnetExchangeOrderRepository: testnetOrders,
      wallet: wallet,
      settingsRepository: settings,
      walletAddressRepository: walletAddress,
      saveUserPreferencesUsecase: savePreferences,
    );
    when(() => settings.fetch()).thenAnswer((_) async => mainnetSettings);
  });

  DcaFailure failureOf(Result<Dca, DcaFailure> result) {
    expect(result, isA<Err<Dca, DcaFailure>>());
    return (result as Err<Dca, DcaFailure>).failure;
  }

  group('SetDcaUsecase', () {
    test('maps a missing lightning address to LightningAddressRequired '
        'without calling the exchange', () async {
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: null,
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaLightningAddressRequiredFailure>());
      expect(failure.logMessage, isNull);
      verifyZeroInteractions(mainnetOrders);
    });

    test(
      'maps an empty default-wallet list to ReceiveAddressFailure',
      () async {
        when(
          () => wallet.getWallets(
            environment: Environment.mainnet,
            onlyDefaults: true,
            onlyBitcoin: true,
            onlyLiquid: false,
          ),
        ).thenAnswer((_) async => []);

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.bitcoin,
        );

        final failure = failureOf(result);
        expect(failure, isA<DcaReceiveAddressFailure>());
        expect(failure.logMessage, isNull);
        verifyZeroInteractions(mainnetOrders);
      },
    );

    test('maps a failing address generation to ReceiveAddressFailure without '
        'logging the wallet identifier', () async {
      when(
        () => wallet.getWallets(
          environment: Environment.mainnet,
          onlyDefaults: true,
          onlyBitcoin: true,
          onlyLiquid: false,
        ),
      ).thenAnswer((_) async => [FakeWallet()]);
      when(
        () => walletAddress.generateNewReceiveAddress(
          walletId: any(named: 'walletId'),
        ),
      ).thenThrow(const WalletError.notFound(_sentinelWalletId));

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.bitcoin,
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaReceiveAddressFailure>());
      // The failure travels into bloc state, so its logMessage is a fixed
      // breadcrumb: the identifier must not survive into it. The raw error
      // still reaches `log.severe`, which is the only sink allowed to see it.
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, 'receive address generation failed');
    });

    test('maps an exchange rejection to OrderCreationFailure without carrying '
        'the raw reason', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenThrow(
        Exception('Failed to create DCA: HTTP 500 apiKey=$_sentinelSecret'),
      );

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@lightning.address',
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaOrderCreationFailure>());
      // A foreign message can embed a credential or a response body. It is
      // logged, never carried by the failure object.
      expect(failure.logMessage, isNot(contains(_sentinelSecret)));
      expect(failure.logMessage, 'createDca rejected');
    });

    test('keeps the flow successful when the order was created but enabling '
        'the preference failed', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => dca);
      when(
        () => savePreferences.execute(dcaEnabled: true),
      ).thenThrow(Exception('prefs write failed'));

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@lightning.address',
      );

      // The recurring buy exists on the exchange: reporting a failure here
      // would tell the user nothing happened and invite a duplicate order.
      expect(result, isA<Ok<Dca, DcaFailure>>());
      expect((result as Ok<Dca, DcaFailure>).value, same(dca));
    });

    test('rethrows an Error instead of turning a bug into a failure', () async {
      when(() => settings.fetch()).thenThrow(StateError('bug'));

      expect(
        () => usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.lightning,
          lightningAddress: 'user@lightning.address',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('returns Ok with the created dca on success', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => dca);
      when(
        () => savePreferences.execute(dcaEnabled: true),
      ).thenAnswer((_) async {});

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@lightning.address',
      );

      expect(result, isA<Ok<Dca, DcaFailure>>());
      expect((result as Ok<Dca, DcaFailure>).value, same(dca));
    });
  });
}
