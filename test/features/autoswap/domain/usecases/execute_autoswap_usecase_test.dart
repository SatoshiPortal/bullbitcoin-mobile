import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/ports/blockchain_port.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/execute_autoswap_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAutoSwapSettingsUsecase extends Mock
    implements GetAutoSwapSettingsUsecase {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class MockBlockchainPort extends Mock implements BlockchainPort {}

class MockGetReceiveAddressUsecase extends Mock
    implements GetReceiveAddressUsecase {}

class MockSwapFacade extends Mock implements SwapFacade {}

class MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class MockLabelsFacade extends Mock implements LabelsFacade {}

Wallet _liquidWallet({int balanceSat = 3000000}) => Wallet(
  origin: 'liquid-1',
  network: Network.liquidMainnet,
  isDefault: true,
  xpubFingerprint: 'fp',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'ext',
  internalPublicDescriptor: 'int',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
);

Wallet _bitcoinWallet() => Wallet(
  origin: 'btc-1',
  network: Network.bitcoinMainnet,
  isDefault: true,
  xpubFingerprint: 'fp',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'ext',
  internalPublicDescriptor: 'int',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(50000),
);

void main() {
  late MockGetAutoSwapSettingsUsecase getSettings;
  late MockWalletRepository walletRepository;
  late MockLiquidWalletRepository liquidWalletRepository;
  late MockBlockchainPort blockchainPort;
  late MockGetReceiveAddressUsecase getReceiveAddress;
  late MockSwapFacade swapFacade;
  late MockBoltzSwapRepository boltzRepository;
  late MockLabelsFacade labelsFacade;

  setUpAll(() {
    registerFallbackValue(OrderSwapEnvironment.mainnet);
    registerFallbackValue(OrderSwapNetwork.liquid);
    registerFallbackValue(OrderSwapNetwork.bitcoin);
    registerFallbackValue(OrderSwapPurpose.autoswap);
    registerFallbackValue(BigInt.from(1000));
    registerFallbackValue(const RelativeFee(25));
    registerFallbackValue(
      NewLabel.tx(transactionId: '', origin: '', label: ''),
    );
  });

  setUp(() {
    getSettings = MockGetAutoSwapSettingsUsecase();
    walletRepository = MockWalletRepository();
    liquidWalletRepository = MockLiquidWalletRepository();
    blockchainPort = MockBlockchainPort();
    getReceiveAddress = MockGetReceiveAddressUsecase();
    swapFacade = MockSwapFacade();
    boltzRepository = MockBoltzSwapRepository();
    labelsFacade = MockLabelsFacade();

    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Ok(
        Label.tx(
          id: 1,
          transactionId: 'txid',
          origin: 'wallet-1',
          label: 'Auto-Transfer',
        ),
      ),
    );
  });

  ExecuteAutoswapUsecase buildUsecase() => ExecuteAutoswapUsecase(
    getSettings: getSettings,
    walletRepository: walletRepository,
    liquidWalletRepository: liquidWalletRepository,
    blockchainPort: blockchainPort,
    getReceiveAddress: getReceiveAddress,
    swapFacade: swapFacade,
    boltzRepositoryFactory: (_) => boltzRepository,
    labelsFacade: labelsFacade,
  );

  void stubWallets({int liquidBalance = 3000000}) {
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
      ),
    ).thenAnswer(
      (_) async => [_liquidWallet(balanceSat: liquidBalance), _bitcoinWallet()],
    );
  }

  group('ExecuteAutoswapUsecase guards', () {
    test('refuses when autoswap is disabled', () async {
      when(
        () => getSettings.execute(),
      ).thenAnswer((_) async => const AutoSwap(enabled: false));

      final result = await buildUsecase().execute();

      expect(
        (result as Err).failure,
        isA<AutoswapDisabledFailure>(),
      );
    });

    test('refuses when the warning has not been acknowledged', () async {
      when(
        () => getSettings.execute(),
      ).thenAnswer((_) async => const AutoSwap(showWarning: true));

      final result = await buildUsecase().execute();

      expect(
        (result as Err).failure,
        isA<AutoswapDisabledFailure>(),
      );
    });

    test('refuses when settings violate a rule', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(
          enabled: true,
          showWarning: false,
          recipientWalletId: null,
        ),
      );

      final result = await buildUsecase().execute();

      expect(
        (result as Err).failure,
        isA<AutoswapInvalidSettingsFailure>(),
      );
    });

    test('refuses when there are no default wallets', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(
          enabled: true,
          showWarning: false,
          recipientWalletId: 'btc-1',
        ),
      );
      when(
        () => walletRepository.getWallets(
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => []);

      final result = await buildUsecase().execute();

      expect(
        (result as Err).failure,
        isA<AutoswapNoDefaultWalletFailure>(),
      );
    });

    test('refuses when balance is below the trigger', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(
          enabled: true,
          showWarning: false,
          recipientWalletId: 'btc-1',
          triggerBalanceSats: 5000000,
        ),
      );
      stubWallets(liquidBalance: 1000000);

      final result = await buildUsecase().execute();

      expect(
        (result as Err).failure,
        isA<AutoswapInsufficientBalanceFailure>(),
      );
    });
  });

  group('ExecuteAutoswapUsecase Exchange path', () {
    test('returns the order local ID on success', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(
          enabled: true,
          showWarning: false,
          recipientWalletId: 'btc-1',
          balanceThresholdSats: 1000000,
          triggerBalanceSats: 2000000,
        ),
      );
      stubWallets();

      when(
        () => swapFacade.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          OrderSwapQuote(
            inAmountSat: BigInt.from(2000000),
            outAmountSat: BigInt.from(1980000),
            inNetwork: OrderSwapNetwork.liquid,
            outNetwork: OrderSwapNetwork.bitcoin,
            inCurrency: 'LBTC',
            outCurrency: 'BTC',
            feeBasisPoints: 100,
            warnings: const [],
          ),
        ),
      );

      when(
        () => getReceiveAddress.execute(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer(
        (_) async => WalletAddress(
          walletId: 'wallet-1',
          address: 'tlq1dest',
          index: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

      final mockOrder = _MockOrderSwapRecord();
      when(
        () => swapFacade.createOrder(
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
          destinationAddress: any(named: 'destinationAddress'),
          fallbackAddress: any(named: 'fallbackAddress'),
          purpose: any(named: 'purpose'),
          environment: any(named: 'environment'),
          sourceWalletId: any(named: 'sourceWalletId'),
          destinationWalletId: any(named: 'destinationWalletId'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => Ok(mockOrder));

      when(
        () => liquidWalletRepository.buildPset(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenAnswer((_) async => 'pset');

      when(
        () => liquidWalletRepository.signPset(
          walletId: any(named: 'walletId'),
          pset: any(named: 'pset'),
        ),
      ).thenAnswer((_) async => 'signed-pset');

      when(
        () => blockchainPort.broadcastLiquidTransaction(
          signedPset: any(named: 'signedPset'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => 'txid-1');

      when(
        () => swapFacade.savePreparedPayin(
          localId: any(named: 'localId'),
          signedTransaction: any(named: 'signedTransaction'),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenAnswer((_) async => Ok(mockOrder));

      when(
        () => swapFacade.markBroadcastUnknown(any()),
      ).thenAnswer((_) async => Ok(mockOrder));

      when(
        () => swapFacade.markPayinBroadcast(
          localId: any(named: 'localId'),
          transactionId: any(named: 'transactionId'),
        ),
      ).thenAnswer((_) async => Ok(mockOrder));

      final result = await buildUsecase().execute();

      expect(result, isA<Ok<String, AutoswapFailure>>());
      verify(
        () => labelsFacade.store(any()),
      ).called(1);
    });

    test('maps a quote failure to AutoswapExecutionFailure', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(
          enabled: true,
          showWarning: false,
          recipientWalletId: 'btc-1',
          balanceThresholdSats: 1000000,
          triggerBalanceSats: 2000000,
        ),
      );
      stubWallets();

      when(
        () => swapFacade.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      ).thenAnswer(
        (_) async => const Err(SwapNetworkFailure('timeout')),
      );

      final result = await buildUsecase().execute();

      expect(
        (result as Err).failure,
        isA<AutoswapExecutionFailure>(),
      );
    });
  });

  // The Boltz path with a null URL is unreachable by construction:
  // `providerMode` returns `.boltz` only when `boltzFallbackUrl != null`.
  // The `AutoswapBoltzServerRequiredFailure` guard in the executor is a
  // safety net, not a reachable code path.
}

class _MockOrderSwapRecord extends Mock implements OrderSwapRecord {
  @override
  String get localId => 'local-1';

  @override
  OrderSwap? get order => _MockOrderSwap();
}

class _MockOrderSwap extends Mock implements OrderSwap {
  @override
  String get payinAddress => 'tlq1payin';

  @override
  BigInt get payinAmountSat => BigInt.from(2000000);
}
