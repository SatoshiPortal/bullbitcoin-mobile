import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoadAutoswapSettingsUsecase extends Mock
    implements LoadAutoswapSettingsUsecase {}

class MockSaveAutoswapSettingsUsecase extends Mock
    implements SaveAutoswapSettingsUsecase {}

class FakeWallet extends Fake implements Wallet {
  @override
  String get id => 'btc';
}

void main() {
  late MockLoadAutoswapSettingsUsecase load;
  late MockSaveAutoswapSettingsUsecase save;

  setUpAll(() => registerFallbackValue(const AutoSwap()));

  AutoSwapSettingsCubit buildCubit() => AutoSwapSettingsCubit(
    loadAutoswapSettingsUsecase: load,
    saveAutoswapSettingsUsecase: save,
  );

  /// A cubit with a loaded, valid form, ready for a save.
  Future<AutoSwapSettingsCubit> loadedCubit({
    BitcoinUnit unit = BitcoinUnit.sats,
    int balanceThresholdSats = 100000,
    int triggerBalanceSats = 250000,
  }) async {
    when(() => load.execute()).thenAnswer(
      (_) async => Ok((
        settings: AutoSwap(
          enabled: true,
          balanceThresholdSats: balanceThresholdSats,
          triggerBalanceSats: triggerBalanceSats,
          feeThresholdPercent: 3,
          recipientWalletId: 'btc',
        ),
        bitcoinUnit: unit,
        bitcoinWallets: <Wallet>[FakeWallet()],
        recipientWalletId: 'btc',
      )),
    );
    final cubit = buildCubit();
    await cubit.loadSettings();
    return cubit;
  }

  setUp(() {
    load = MockLoadAutoswapSettingsUsecase();
    save = MockSaveAutoswapSettingsUsecase();
    when(() => save.execute(any())).thenAnswer((_) async => const Ok(null));
  });

  group('AutoSwapSettingsCubit loading', () {
    test('populates the form from the loaded settings', () async {
      final cubit = await loadedCubit();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.amountThresholdInput, '100000');
      expect(cubit.state.triggerBalanceSatsInput, '250000');
      expect(cubit.state.enabledToggle, isTrue);
      expect(cubit.state.selectedBitcoinWalletId, 'btc');
      await cubit.close();
    });

    test('holds the typed failure when loading fails', () async {
      // Before this migration the cubit stored an l10n key name that no widget
      // ever read, so a load failure was invisible.
      when(() => load.execute()).thenAnswer(
        (_) async =>
            const Err(AutoswapSettingsUnavailableFailure('_Exception')),
      );
      final cubit = buildCubit();

      await cubit.loadSettings();

      expect(cubit.state.failure, isA<AutoswapSettingsUnavailableFailure>());
      expect(cubit.state.loading, isFalse);
      await cubit.close();
    });
  });

  group('AutoSwapSettingsCubit saving', () {
    test('persists the converted sats on a valid form', () async {
      final cubit = await loadedCubit();

      await cubit.updateSettings();

      expect(cubit.state.successfullySaved, isTrue);
      final saved =
          verify(() => save.execute(captureAny())).captured.single as AutoSwap;
      expect(saved.balanceThresholdSats, 100000);
      expect(saved.triggerBalanceSats, 250000);
      expect(saved.recipientWalletId, 'btc');
      await cubit.close();
    });

    test('converts a btc-denominated form to sats', () async {
      final cubit = await loadedCubit(unit: BitcoinUnit.btc);
      // 0.001 BTC target, 0.002 BTC trigger
      cubit.onAmountThresholdChanged('0.001');
      cubit.onTriggerBalanceChanged('0.002');

      await cubit.updateSettings();

      final saved =
          verify(() => save.execute(captureAny())).captured.last as AutoSwap;
      expect(saved.balanceThresholdSats, 100000);
      expect(saved.triggerBalanceSats, 200000);
      await cubit.close();
    });

    test('puts a recipient failure in the shared slot', () async {
      when(() => save.execute(any())).thenAnswer(
        (_) async => const Err(AutoswapRecipientWalletRequiredFailure()),
      );
      final cubit = await loadedCubit();

      await cubit.updateSettings();

      expect(
        cubit.state.failure,
        isA<AutoswapRecipientWalletRequiredFailure>(),
      );
      expect(cubit.state.successfullySaved, isFalse);
      await cubit.close();
    });

    test('disabling saves without a recipient wallet', () async {
      // The path the toggle takes when switching auto swap off: it must not
      // demand a recipient, or turning the feature off would be impossible.
      final cubit = await loadedCubit();
      cubit.onWalletSelected(null);

      cubit.onEnabledToggleChanged(false);
      await Future<void>.delayed(Duration.zero);

      final saved =
          verify(() => save.execute(captureAny())).captured.single as AutoSwap;
      expect(saved.enabled, isFalse);
      expect(saved.showWarning, isFalse);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    // The rules themselves live on the AutoSwap entity and are tested there.
    // What the cubit owns is placing the returned failure next to the field it
    // is about, so the form can render it inline.
    test('puts a balance-threshold failure on the amount field', () async {
      when(() => save.execute(any())).thenAnswer(
        (_) async => const Err(AutoswapBalanceThresholdTooLowFailure(50000)),
      );
      final cubit = await loadedCubit();

      await cubit.updateSettings();

      expect(
        cubit.state.amountThresholdFailure,
        isA<AutoswapBalanceThresholdTooLowFailure>(),
      );
      expect(cubit.state.failure, isNull);
      expect(cubit.state.successfullySaved, isFalse);
      await cubit.close();
    });

    test('puts a trigger-balance failure on the trigger field', () async {
      when(() => save.execute(any())).thenAnswer(
        (_) async => const Err(AutoswapTriggerBalanceTooLowFailure()),
      );
      final cubit = await loadedCubit();

      await cubit.updateSettings();

      expect(
        cubit.state.triggerBalanceFailure,
        isA<AutoswapTriggerBalanceTooLowFailure>(),
      );
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('puts a fee-threshold failure on the fee field', () async {
      when(() => save.execute(any())).thenAnswer(
        (_) async => const Err(AutoswapFeeThresholdTooHighFailure(10)),
      );
      final cubit = await loadedCubit();

      await cubit.updateSettings();

      expect(
        cubit.state.feeThresholdFailure,
        isA<AutoswapFeeThresholdTooHighFailure>(),
      );
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('falls back to the default fee when the field is empty', () async {
      final cubit = await loadedCubit();
      cubit.onFeeThresholdChanged('');

      await cubit.updateSettings();

      final saved =
          verify(() => save.execute(captureAny())).captured.single as AutoSwap;
      expect(saved.feeThresholdPercent, 3.0);
      await cubit.close();
    });

    test('a save failure does not report success', () async {
      final cubit = await loadedCubit();
      when(() => save.execute(any())).thenAnswer(
        (_) async => const Err(AutoswapSettingsSaveFailure('_Exception')),
      );

      await cubit.updateSettings();

      expect(cubit.state.failure, isA<AutoswapSettingsSaveFailure>());
      expect(cubit.state.successfullySaved, isFalse);
      await cubit.close();
    });
  });

  group('AutoSwapSettingsCubit live validation', () {
    test(
      'flags a below-minimum amount as it is typed, but not an empty field',
      () async {
        final cubit = await loadedCubit();

        cubit.onAmountThresholdChanged('1000');
        expect(
          cubit.state.amountThresholdFailure,
          isA<AutoswapBalanceThresholdTooLowFailure>(),
        );

        // Clearing the field is not an error — the user is still typing.
        cubit.onAmountThresholdChanged('');
        expect(cubit.state.amountThresholdFailure, isNull);
        await cubit.close();
      },
    );

    test('flags a too-low trigger balance as it is typed', () async {
      final cubit = await loadedCubit();

      cubit.onTriggerBalanceChanged('150000');

      expect(
        cubit.state.triggerBalanceFailure,
        isA<AutoswapTriggerBalanceTooLowFailure>(),
      );
      await cubit.close();
    });
  });
}
