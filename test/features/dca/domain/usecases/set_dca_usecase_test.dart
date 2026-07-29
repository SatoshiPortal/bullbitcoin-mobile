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
      // logMessage is logged by consumers too, so the identifier must be
      // absent from it as well as from the log call.
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, 'WalletNotFound');
    });

    test('maps an exchange rejection to OrderCreationFailure; the raw reason '
        'stays out of the UI path', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenThrow(
        Exception('Failed to create DCA: HTTP 500 apiKey=super-secret'),
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
      // The raw reason is preserved for logs only — never rendered, since the
      // l10n extension ignores logMessage by construction.
      expect(failure.logMessage, contains('Failed to create DCA'));
    });

    test('maps a failure while enabling the preference (after the order was '
        'created) to UnexpectedFailure', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer(
        (_) async => Dca(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.lightning,
          address: 'user@lightning.address',
          nextPurchaseDate: DateTime(2026),
        ),
      );
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

      expect(failureOf(result), isA<DcaUnexpectedFailure>());
    });

    test('returns Ok with the created dca on success', () async {
      final dca = Dca(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        address: 'user@lightning.address',
        nextPurchaseDate: DateTime(2026),
      );
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
