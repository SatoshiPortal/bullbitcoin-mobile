import '../../../core/exchange/fake_exchange_users.dart';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:bull_exchange/testing.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../fake_index_price_reader.dart';

class _ExchangeUsers extends Mock implements ExchangeUserOperations {}

class _MockGetSettings extends Mock implements Preferences {}

class _Inventory extends Mock implements WalletInventory {}

class _Native extends Mock implements WalletNativeLifecycle {}

class _MockGetNetworkFees extends Mock implements Fees {}

class _MockFeeOptions extends Mock implements FeeOptions {}

/// A reason of the shape these core reads produce, quoting a key.
const _rawReason = 'DioException 500 apikey=secret123';

SettingsEntity _settings({Environment environment = Environment.mainnet}) =>
    SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  late _ExchangeUsers getUserSummary;
  late _MockGetSettings getSettings;
  late _Inventory getWallets;
  late _Native getReceiveAddress;
  late _MockGetNetworkFees getNetworkFees;
  late FakeIndexPriceReader getIndexPrice;
  late LoadBuyContextUsecase usecase;

  setUp(() {
    getUserSummary = _ExchangeUsers();
    getSettings = _MockGetSettings();
    getWallets = _Inventory();
    getReceiveAddress = _Native();
    getNetworkFees = _MockGetNetworkFees();
    getIndexPrice = FakeIndexPriceReader();
    usecase = LoadBuyContextUsecase(
      exchange: fakeExchangeUsers(getUserSummary, getUserSummary),
      getSettingsUsecase: getSettings,
      payouts: ExchangePayoutWallets(getWallets, getReceiveAddress),
      fees: getNetworkFees,
      getIndexPrice: getIndexPrice.call,
    );
  });

  test('does not publish raw summary exceptions', () async {
    when(getSettings.fetch).thenAnswer((_) async => Ok(_settings()));
    when(getUserSummary.getUserSummary).thenThrow(Exception(_rawReason));
    final result = await usecase.userSummaryAndSettings();
    expect(result, isA<Err<Object, BuyFailure>>());
    expect(
      (result as Err<Object, BuyFailure>).failure.logMessage,
      isNot(contains(_rawReason)),
    );
  });

  test('looks up only the two chains in the active environment', () async {
    when(() => getWallets.walletsForNetwork(BitcoinNetwork.testnet))
        .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
    when(() => getWallets.walletsForNetwork(LiquidNetwork.testnet))
        .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
    final result = await usecase.wallets(Environment.testnet);
    expect((result as Ok<List<WalletRegistration>, BuyFailure>).value, isEmpty);
    verifyInOrder([
      () => getWallets.walletsForNetwork(BitcoinNetwork.testnet),
      () => getWallets.walletsForNetwork(LiquidNetwork.testnet),
    ]);
    verifyNoMoreInteractions(getWallets);
  });

  test('does not treat a locked inventory as an empty wallet list', () async {
    when(() => getWallets.walletsForNetwork(BitcoinNetwork.mainnet))
        .thenAnswer((_) async => const Err(KeystoreLockedFailure()));
    final result = await usecase.wallets(Environment.mainnet);
    expect(result, isA<Err<List<WalletRegistration>, BuyFailure>>());
    verifyZeroInteractions(getReceiveAddress);
  });

  test('prefers a unique Liquid default without breaking a tie', () {
    final bitcoin = walletRegistrationForTesting(
      id: 'bitcoin',
      network: BitcoinNetwork.mainnet,
      isDefault: true,
    );
    final liquid = walletRegistrationForTesting(
      id: 'liquid',
      network: LiquidNetwork.mainnet,
      isDefault: true,
    );
    final secondLiquid = walletRegistrationForTesting(
      id: 'liquid-duplicate',
      network: LiquidNetwork.mainnet,
      isDefault: true,
    );
    expect(
      LoadBuyContextUsecase.initialWallet([bitcoin, liquid]),
      same(liquid),
    );
    expect(LoadBuyContextUsecase.initialWallet([bitcoin]), same(bitcoin));
    expect(
      LoadBuyContextUsecase.initialWallet([bitcoin, liquid, secondLiquid]),
      isNull,
    );
  });

  test(
    'uses the native current address only while the wallet is authorized',
    () async {
      final wallet = walletRegistrationForTesting(
        id: 'buy-wallet',
        network: BitcoinNetwork.mainnet,
      );
      final key = WalletKey(id: wallet.id, network: wallet.network);
      const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
      when(() => getWallets.readWallet(wallet.id))
          .thenAnswer((_) async => Ok(wallet));
      when(() => getReceiveAddress.receive(key, advance: false))
          .thenAnswer((_) async => const Ok((address: address, index: 2)));
      final issued = await usecase.receiveAddress(wallet: wallet);
      expect((issued as Ok<String, BuyFailure>).value, address);
      verify(() => getWallets.readWallet(wallet.id)).called(2);

      var reads = 0;
      when(() => getWallets.readWallet(wallet.id)).thenAnswer(
        (_) async =>
            ++reads == 1 ? Ok(wallet) : const Err(KeystoreLockedFailure()),
      );
      final invalidated = await usecase.receiveAddress(wallet: wallet);
      expect(invalidated, isA<Err<String, BuyFailure>>());
      verify(() => getReceiveAddress.receive(key, advance: false)).called(2);
    },
  );

  test('refuses an address issued for the wrong network', () async {
    final wallet = walletRegistrationForTesting(
      id: 'testnet-wallet',
      network: BitcoinNetwork.testnet,
    );
    final key = WalletKey(id: wallet.id, network: wallet.network);
    const mainnetAddress = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
    when(() => getWallets.readWallet(wallet.id))
        .thenAnswer((_) async => Ok(wallet));
    when(() => getReceiveAddress.receive(key, advance: false))
        .thenAnswer((_) async => const Ok((address: mainnetAddress, index: 0)));

    expect(
      await usecase.receiveAddress(wallet: wallet),
      isA<Err<String, BuyFailure>>(),
    );
  });

  test('returns Liquid fees on the configured testnet', () async {
    final fees = _MockFeeOptions();
    when(
      getSettings.fetch,
    ).thenAnswer((_) async => Ok(_settings(environment: Environment.testnet)));
    when(() => getNetworkFees.estimate(LiquidNetwork.testnet))
        .thenAnswer((_) async => Ok(fees));

    final result = await usecase.networkFees(isLiquid: true);

    expect((result as Ok<FeeOptions, BuyFailure>).value, fees);
  });

  test('a failed fee read is sanitized', () async {
    when(getSettings.fetch).thenAnswer((_) async => Ok(_settings()));
    when(() => getNetworkFees.estimate(BitcoinNetwork.mainnet))
        .thenAnswer((_) async => const Err(FeeEstimateUnavailableFailure()));

    expect(
      await usecase.networkFees(isLiquid: false),
      isA<Err<FeeOptions, BuyFailure>>(),
    );
  });

  test('an unavailable environment skips fee estimation', () async {
    when(getSettings.fetch)
        .thenAnswer((_) async => const Err(PreferencesReadFailure()));

    final result = await usecase.networkFees(isLiquid: false);

    expect(result, isA<Err<FeeOptions, BuyFailure>>());
    verifyZeroInteractions(getNetworkFees);
  });

  group('satsToCurrency', () {
    setUp(
      () => when(getSettings.fetch).thenAnswer((_) async => Ok(_settings())),
    );

    test(
      'values the amount at the mainnet price of the settings currency',
      () async {
        getIndexPrice.fiatAmount = 100000;

        final result = await usecase.satsToCurrency(
          amountSat: BigInt.from(50000),
        );

        expect((result as Ok<double, BuyFailure>).value, 50);
        expect(getIndexPrice.requests.single, (
          network: BitcoinNetwork.mainnet,
          currency: SupportedCurrency.usd,
        ));
      },
    );

    test('without an amount, gives the price of one bitcoin', () async {
      getIndexPrice.fiatAmount = 100000;

      final result = await usecase.satsToCurrency(currencyCode: 'CAD');

      expect((result as Ok<double, BuyFailure>).value, 100000);
      expect(getIndexPrice.requests.single.currency, SupportedCurrency.cad);
    });

    test('asks the testnet price in the testnet environment', () async {
      when(getSettings.fetch).thenAnswer(
        (_) async => Ok(_settings(environment: Environment.testnet)),
      );

      final result = await usecase.satsToCurrency();

      expect(result, isA<Ok<double, BuyFailure>>());
      expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
    });

    test('no price is an unavailable quote, not a zero rate', () async {
      getIndexPrice.failure = const PricerNetworkFailure('offline');

      final result = await usecase.satsToCurrency(currencyCode: 'CAD');

      expect(
        (result as Err<double, BuyFailure>).failure,
        isA<BuyQuoteUnavailableFailure>(),
      );
    });

    test('a currency without a price is unexpected, never asked', () async {
      final result = await usecase.satsToCurrency(currencyCode: 'JPY');

      expect(
        (result as Err<double, BuyFailure>).failure,
        isA<BuyUnexpectedFailure>(),
      );
      expect(getIndexPrice.requests, isEmpty);
    });

    test('a failed settings read is sanitized', () async {
      when(getSettings.fetch).thenThrow(Exception(_rawReason));

      expect(
        await usecase.satsToCurrency(currencyCode: 'CAD'),
        isA<Err<double, BuyFailure>>(),
      );
      expect(getIndexPrice.requests, isEmpty);
    });
  });
}
