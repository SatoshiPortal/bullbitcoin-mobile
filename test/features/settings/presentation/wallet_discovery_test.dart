import 'package:primitives/primitives.dart' show Ok, Err;

import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/discover_wallet_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/wallet_discovery_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_discovery_button.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullFadingLinearProgress;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in [
    const WalletDiscoveryUnavailableFailure(),
    const WalletDiscoverySyncFailure(),
  ]) {
    test('settings maps ${failure.runtimeType} to its own failure', () async {
      final usecase = DiscoverWalletUsecase(
        WalletFacade(
          const Stream.empty(),
          discoverWallet: (_) async => Err(failure),
        ),
      );
      expect(
        await usecase.execute('wallet'),
        isA<Err<void, SettingsFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SettingsWalletSyncFailure>(),
        ),
      );
    });
  }

  for (final fails in [false, true]) {
    testWidgets(
      'button stays busy, deduplicates and shows outcome (failure=$fails)',
      (tester) async {
        final gate = Completer<Result<void, WalletDiscoveryFailure>>();
        final ids = <String>[];
        final cubit = WalletDiscoveryCubit(
          DiscoverWalletUsecase(
            WalletFacade(
              const Stream.empty(),
              discoverWallet: (id) {
                ids.add(id);
                return gate.future;
              },
            ),
          ),
        );
        addTearDown(cubit.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider.value(
                value: cubit,
                child: const WalletDiscoveryButton(walletId: 'target'),
              ),
            ),
          ),
        );
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.text(l10n.walletDiscoveryButton));
        await tester.pump();
        expect(cubit.state, isA<WalletDiscoveryRunning>());
        expect(
          tester.widget<BullButton>(find.byType(BullButton)).disabled,
          isTrue,
        );
        expect(
          tester
              .widget<BullFadingLinearProgress>(
                find.byType(BullFadingLinearProgress),
              )
              .trigger,
          isTrue,
        );
        await cubit.discover('target');
        expect(ids, ['target']);
        gate.complete(
          fails ? const Err(WalletDiscoverySyncFailure()) : const Ok(null),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<BullButton>(find.byType(BullButton)).disabled,
          isFalse,
        );
        expect(
          find.text(
            fails ? l10n.walletDiscoveryFailed : l10n.walletDiscoverySucceeded,
          ),
          findsOneWidget,
        );
      },
    );
  }

  test('leaving settings does not cancel the queued discovery', () async {
    final gate = Completer<Result<void, WalletDiscoveryFailure>>();
    final cubit = WalletDiscoveryCubit(
      DiscoverWalletUsecase(
        WalletFacade(const Stream.empty(), discoverWallet: (_) => gate.future),
      ),
    );
    final pending = cubit.discover('wallet');
    await cubit.close();
    gate.complete(const Ok(null));
    await pending;
  });
}
