import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/boltz_server_url.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/swap_provider_mode.dart';
import 'package:bb_mobile/features/autoswap/presentation/swap_provider_availability_cubit.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAutoSwapSettingsUsecase extends Mock
    implements GetAutoSwapSettingsUsecase {}

class MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late MockGetAutoSwapSettingsUsecase getSettings;
  late MockSwapFacade swapFacade;

  setUpAll(() {
    registerFallbackValue(OrderSwapEnvironment.mainnet);
    registerFallbackValue(OrderSwapNetwork.liquid);
    registerFallbackValue(OrderSwapNetwork.bitcoin);
    registerFallbackValue(BigInt.from(1000));
  });

  setUp(() {
    getSettings = MockGetAutoSwapSettingsUsecase();
    swapFacade = MockSwapFacade();
  });

  SwapProviderAvailabilityCubit buildCubit() =>
      SwapProviderAvailabilityCubit(
        getAutoSwapSettingsUsecase: getSettings,
        swapFacade: swapFacade,
      );

  group('SwapProviderAvailabilityCubit', () {
    test('skips the check when a Boltz URL is configured', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => AutoSwap(
          boltzFallbackUrl: BoltzServerUrl.parse('https://boltz.example.com'),
        ),
      );
      final cubit = buildCubit();

      await cubit.checkAvailability();

      expect(cubit.state.mode, SwapProviderMode.boltz);
      expect(cubit.state.exchangeUnavailable, isFalse);
      verifyNever(
        () => swapFacade.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      );
      await cubit.close();
    });

    test('emits exchangeUnavailable on HTTP 418', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(),
      );
      when(
        () => swapFacade.getQuote(
          environment: any(named: 'environment'),
          amountSat: any(named: 'amountSat'),
          isInAmountFixed: any(named: 'isInAmountFixed'),
          inNetwork: any(named: 'inNetwork'),
          outNetwork: any(named: 'outNetwork'),
        ),
      ).thenAnswer(
        (_) async => const Err(SwapProviderUnavailableFailure()),
      );
      final cubit = buildCubit();

      await cubit.checkAvailability();

      expect(cubit.state.mode, SwapProviderMode.exchange);
      expect(cubit.state.exchangeUnavailable, isTrue);
      await cubit.close();
    });

    test('does not prompt on a generic network error', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(),
      );
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
      final cubit = buildCubit();

      await cubit.checkAvailability();

      expect(cubit.state.exchangeUnavailable, isFalse);
      await cubit.close();
    });

    test('stays quiet when the Exchange answers normally', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const AutoSwap(),
      );
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
            inAmountSat: BigInt.from(1000),
            outAmountSat: BigInt.from(990),
            inNetwork: OrderSwapNetwork.liquid,
            outNetwork: OrderSwapNetwork.bitcoin,
            inCurrency: 'LBTC',
            outCurrency: 'BTC',
            feeBasisPoints: 100,
            warnings: const [],
          ),
        ),
      );
      final cubit = buildCubit();

      await cubit.checkAvailability();

      expect(cubit.state.exchangeUnavailable, isFalse);
      expect(cubit.state.checking, isFalse);
      await cubit.close();
    });
  });
}
