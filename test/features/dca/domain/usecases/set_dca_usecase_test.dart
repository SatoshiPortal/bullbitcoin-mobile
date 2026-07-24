import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/await_cbf_sync_inactive_usecase.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class _MockAwaitCbfSyncInactiveUsecase extends Mock
    implements AwaitCbfSyncInactiveUsecase {}

class _MockWallet extends Mock implements Wallet {}

SettingsEntity _buildSettings() {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
  );
}

WalletAddress _buildAddress({String walletId = 'default-wallet'}) {
  return WalletAddress(
    walletId: walletId,
    index: 0,
    address: 'bc1qgeneratedaddress',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  late _MockExchangeOrderRepository mainnetExchangeOrderRepository;
  late _MockExchangeOrderRepository testnetExchangeOrderRepository;
  late _MockWalletRepository walletRepository;
  late _MockSettingsRepository settingsRepository;
  late _MockWalletAddressRepository walletAddressRepository;
  late _MockAwaitCbfSyncInactiveUsecase awaitCbfSyncInactive;
  late SetDcaUsecase usecase;
  late _MockWallet defaultWallet;

  setUpAll(() {
    registerFallbackValue(FiatCurrency.usd);
    registerFallbackValue(DcaBuyFrequency.daily);
    registerFallbackValue(DcaNetwork.bitcoin);
  });

  setUp(() {
    mainnetExchangeOrderRepository = _MockExchangeOrderRepository();
    testnetExchangeOrderRepository = _MockExchangeOrderRepository();
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    walletAddressRepository = _MockWalletAddressRepository();
    awaitCbfSyncInactive = _MockAwaitCbfSyncInactiveUsecase();
    defaultWallet = _MockWallet();

    usecase = SetDcaUsecase(
      mainnetExchangeOrderRepository: mainnetExchangeOrderRepository,
      testnetExchangeOrderRepository: testnetExchangeOrderRepository,
      wallet: walletRepository,
      settingsRepository: settingsRepository,
      walletAddressRepository: walletAddressRepository,
      awaitCbfSyncInactiveUsecase: awaitCbfSyncInactive,
    );

    when(() => defaultWallet.id).thenReturn('default-wallet');
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _buildSettings());
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
      ),
    ).thenAnswer((_) async => [defaultWallet]);
    when(
      () => awaitCbfSyncInactive.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => walletAddressRepository.generateNewReceiveAddress(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => _buildAddress());
    when(
      () => mainnetExchangeOrderRepository.createDca(
        amount: any(named: 'amount'),
        currency: any(named: 'currency'),
        frequency: any(named: 'frequency'),
        network: any(named: 'network'),
        address: any(named: 'address'),
      ),
    ).thenAnswer(
      (invocation) async => Dca(
        amount: invocation.namedArguments[#amount] as double,
        currency: invocation.namedArguments[#currency] as FiatCurrency,
        frequency: invocation.namedArguments[#frequency] as DcaBuyFrequency,
        network: invocation.namedArguments[#network] as DcaNetwork,
        address: invocation.namedArguments[#address] as String,
        nextPurchaseDate: DateTime(2026),
      ),
    );
  });

  test(
    'a Bitcoin DCA waits for the active CBF sync on the default wallet to '
    'settle before revealing (and persisting) a new receive address',
    () async {
      await usecase.execute(
        amount: 10,
        currency: FiatCurrency.usd,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.bitcoin,
      );

      verifyInOrder([
        () => awaitCbfSyncInactive.execute(walletId: 'default-wallet'),
        () => walletAddressRepository.generateNewReceiveAddress(
          walletId: 'default-wallet',
        ),
      ]);
    },
  );

  test(
    'the resulting DCA order carries the freshly revealed address',
    () async {
      final dca = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.usd,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.bitcoin,
      );

      expect(dca.address, 'bc1qgeneratedaddress');
    },
  );

  test('a Lightning DCA never touches the wallet address repository or the '
      'CBF wait — a lightning address is used as-is', () async {
    final dca = await usecase.execute(
      amount: 10,
      currency: FiatCurrency.usd,
      frequency: DcaBuyFrequency.daily,
      network: DcaNetwork.lightning,
      lightningAddress: 'user@example.com',
    );

    expect(dca.address, 'user@example.com');
    verifyNever(
      () => awaitCbfSyncInactive.execute(walletId: any(named: 'walletId')),
    );
    verifyNever(
      () => walletAddressRepository.generateNewReceiveAddress(
        walletId: any(named: 'walletId'),
      ),
    );
  });

  test(
    'a CBF wait failure propagates without ever revealing a new address',
    () async {
      when(
        () => awaitCbfSyncInactive.execute(walletId: 'default-wallet'),
      ).thenThrow(Exception('boom'));

      await expectLater(
        usecase.execute(
          amount: 10,
          currency: FiatCurrency.usd,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.bitcoin,
        ),
        throwsA(isA<Exception>()),
      );

      verifyNever(
        () => walletAddressRepository.generateNewReceiveAddress(
          walletId: any(named: 'walletId'),
        ),
      );
    },
  );
}
