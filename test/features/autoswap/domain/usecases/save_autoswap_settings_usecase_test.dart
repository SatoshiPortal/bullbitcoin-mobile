import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveAutoSwapSettingsUsecase extends Mock
    implements SaveAutoSwapSettingsUsecase {}

/// A wallet id is the descriptor origin, so it embeds the master key
/// fingerprint. Routed through the failing path below so the failure can be
/// searched for it: it must never reach [Failure.logMessage], which any
/// consumer may log or render.
const _sentinelWalletId = 'wpkh([da7ab10b/84h/0h/0h])';

const _settings = AutoSwap(
  enabled: true,
  balanceThresholdSats: 100000,
  triggerBalanceSats: 200000,
  recipientWalletId: _sentinelWalletId,
);

void main() {
  late MockSaveAutoSwapSettingsUsecase saveCore;
  late SaveAutoswapSettingsUsecase usecase;

  setUpAll(() => registerFallbackValue(const AutoSwap()));

  setUp(() {
    saveCore = MockSaveAutoSwapSettingsUsecase();
    usecase = SaveAutoswapSettingsUsecase(
      saveAutoSwapSettingsUsecase: saveCore,
    );
  });

  AutoswapFailure failureOf(Result<void, AutoswapFailure> result) {
    expect(result, isA<Err<void, AutoswapFailure>>());
    return (result as Err<void, AutoswapFailure>).failure;
  }

  group('SaveAutoswapSettingsUsecase', () {
    test('delegates the settings to the shared usecase', () async {
      when(() => saveCore.execute(any())).thenAnswer((_) async {});

      final result = await usecase.execute(_settings);

      expect(result, isA<Ok<void, AutoswapFailure>>());
      verify(() => saveCore.execute(_settings)).called(1);
    });

    test('refuses settings the entity rejects, without writing', () async {
      // The boundary validates so no caller can persist broken settings.
      final result = await usecase.execute(
        _settings.copyWith(balanceThresholdSats: 1000),
      );

      expect(failureOf(result), isA<AutoswapBalanceThresholdTooLowFailure>());
      verifyNever(() => saveCore.execute(any()));
    });

    test('maps each violation to its failure', () async {
      expect(
        failureOf(
          await usecase.execute(_settings.copyWith(recipientWalletId: null)),
        ),
        isA<AutoswapRecipientWalletRequiredFailure>(),
      );
      expect(
        failureOf(
          await usecase.execute(_settings.copyWith(triggerBalanceSats: 1)),
        ),
        isA<AutoswapTriggerBalanceTooLowFailure>(),
      );
      expect(
        failureOf(
          await usecase.execute(_settings.copyWith(feeThresholdPercent: 99)),
        ),
        isA<AutoswapFeeThresholdTooHighFailure>(),
      );
      verifyNever(() => saveCore.execute(any()));
    });

    test('maps a failing write to SaveFailure, keeping the raw reason out of '
        'the failure', () async {
      when(() => saveCore.execute(any())).thenThrow(
        Exception('drift write failed for $_sentinelWalletId xprv9sSecret'),
      );

      final result = await usecase.execute(_settings);

      expect(result, isA<Err<void, AutoswapFailure>>());
      final failure = (result as Err<void, AutoswapFailure>).failure;
      expect(failure, isA<AutoswapSettingsSaveFailure>());
      // Type only. This assertion is what makes swapping `e.runtimeType` for
      // `e.toString()` fail loudly instead of shipping a leak.
      expect(failure.logMessage, '_Exception');
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, isNot(contains('xprv')));
    });
  });
}
