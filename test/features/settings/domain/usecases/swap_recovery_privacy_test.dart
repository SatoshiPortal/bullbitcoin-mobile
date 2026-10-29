import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restore_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/rescue_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/restore_settings_swaps_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/rescue_settings_swap_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Swaps extends Mock implements BoltzSwapRepository {}

class _Rescue extends Mock implements RescueSwapUsecase {}

class _Restored extends Fake implements RestoredSwap {}

void main() {
  test(
    'the restore privacy guard survives the core boundary as a localized failure',
    () async {
      final settings = _Settings();
      final swaps = _Swaps();
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(() => swaps.restoreSwaps(isTestnet: false)).thenThrow(
        const BitcoinSyncOperationException(CbfRemoteLookupForbiddenFailure()),
      );
      final core = RestoreSwapsUsecase(
        swapRepository: swaps,
        settingsRepository: settings,
      );
      final result = await RestoreSettingsSwapsUsecase(restore: core).execute();
      expect(result, isA<Err<List<RestorableSwap>, SettingsFailure>>());
      if (result case Err(:final failure)) {
        expect(failure, isA<SettingsSwapRecoveryUnavailableFailure>());
      }
      verifyNever(() => swaps.getAllSwaps());
    },
  );
  test(
    'CBF rescue remains unavailable without exposing infrastructure strings',
    () async {
      final core = _Rescue();
      final restored = _Restored();
      when(
        () => core.execute(
          restored: restored,
          selectedWalletId: 'private-wallet',
        ),
      ).thenThrow(
        const BitcoinSyncOperationException(CbfRemoteLookupForbiddenFailure()),
      );
      final result = await RescueSettingsSwapUsecase(
        rescue: core,
      ).execute(restored: restored, selectedWalletId: 'private-wallet');
      if (result case Err(:final failure)) {
        expect(failure, isA<SettingsSwapRecoveryUnavailableFailure>());
        expect(failure.logMessage, isNull);
      } else {
        fail('Recovery must remain guarded');
      }
    },
  );
  for (final locale in ['en', 'fr']) {
    testWidgets('swap recovery deferral is localized in $locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(
              const SettingsSwapRecoveryUnavailableFailure().toTranslated(
                context,
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining(
          locale == 'en'
              ? 'Use an Electrum wallet as the destination.'
              : 'Choisissez un portefeuille Electrum comme destination.',
        ),
        findsOneWidget,
      );
    });
  }
}
