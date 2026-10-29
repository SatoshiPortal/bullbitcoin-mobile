import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/continue_cbf_on_mobile_data_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/set_cbf_wifi_only_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/watch_cbf_network_policy_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_status.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_network_preferences.dart';
import 'package:bb_mobile/features/wallet_sync/ui/widgets/wallet_recovery_panel.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class _Policy implements CbfNetworkPolicyPort {
  final _changes = StreamController<CbfNetworkPolicyState>.broadcast(
    sync: true,
  );
  CbfNetworkPolicyState _current;
  int consents = 0;
  final writes = <bool>[];

  _Policy({bool wifiOnly = false})
    : _current = CbfNetworkPolicyState(
        initialized: true,
        available: true,
        metered: true,
        wifiOnly: wifiOnly,
      );

  @override
  CbfNetworkPolicyState get current => _current;

  @override
  Stream<CbfNetworkPolicyState> watch() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(controller.add);
    controller.add(_current);
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<Result<void, WalletTransactionSyncFailure>> setWifiOnly(
    bool enabled,
  ) async {
    writes.add(enabled);
    _current = CbfNetworkPolicyState(
      initialized: true,
      available: _current.available,
      metered: _current.metered,
      wifiOnly: enabled,
    );
    _changes.add(_current);
    return const Ok(null);
  }

  @override
  void continueOnMobileData() {
    consents++;
    _current = CbfNetworkPolicyState(
      initialized: true,
      available: _current.available,
      metered: _current.metered,
      wifiOnly: _current.wifiOnly,
      mobileDataOverride: true,
    );
    _changes.add(_current);
  }

  Future<void> dispose() => _changes.close();
}

Widget _app(Widget child, {required bool dark, required String locale}) =>
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.themeData(dark ? AppThemeType.dark : AppThemeType.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

WalletSyncStatus _paused(_Policy policy) => WalletSyncStatus(
  networkPolicy: policy.current,
  progress: const BitcoinSyncProgress(
    key: WalletNetworkKey('public-wallet', 'bitcoin', 'mainnet'),
    phase: BitcoinSyncPhase.checkingBlocks,
    fraction: 0.5,
    startHeight: 1000,
    reachedHeight: 2000,
    targetHeight: 3000,
    isRecovery: true,
    operationId: 1,
  ),
);

Future<void> _close(WidgetTester tester) async {
  BullSnackBar.dismiss();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  for (final dark in [false, true]) {
    for (final locale in ['en', 'fr']) {
      final consent = locale == 'fr'
          ? 'Continuer sur données mobiles'
          : 'Continue on mobile data';
      final title = locale == 'fr' ? 'Wi-Fi seulement' : 'Wi-Fi only';
      final paused = locale == 'fr'
          ? 'Synchronisation en pause pour économiser les données mobiles.'
          : 'Sync paused to save mobile data.';

      testWidgets(
        'Wi-Fi preference defaults off and consent preserves it $locale/$dark',
        (tester) async {
          final policy = _Policy();
          addTearDown(policy.dispose);
          await tester.pumpWidget(
            _app(
              WalletSyncNetworkPreferences(
                watch: WatchCbfNetworkPolicyUsecase(policy: policy),
                set: SetCbfWifiOnlyUsecase(policy: policy),
                continueOnMobileData: ContinueCbfOnMobileDataUsecase(
                  policy: policy,
                ),
              ),
              dark: dark,
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          expect(
            tester.widget<BullSwitch>(find.byType(BullSwitch)).value,
            isFalse,
          );
          expect(find.text(consent), findsNothing);

          await tester.tap(find.byType(BullSwitch));
          await tester.pumpAndSettle();
          expect(policy.writes, [true]);
          expect(
            tester.widget<BullSwitch>(find.byType(BullSwitch)).value,
            isTrue,
          );
          expect(find.text(paused), findsOneWidget);
          await tester.ensureVisible(find.text(consent));
          await tester.tap(find.text(consent));
          await tester.pumpAndSettle();
          expect(policy.consents, 1);
          expect(policy.writes, [true]);
          expect(
            tester.widget<BullSwitch>(find.byType(BullSwitch)).value,
            isTrue,
          );
          expect(find.text(paused), findsNothing);
          expect(find.text(consent), findsNothing);
          await _close(tester);
        },
      );

      testWidgets(
        'paused recovery retains progress and exposes consent/settings $locale/$dark',
        (tester) async {
          final policy = _Policy(wifiOnly: true);
          addTearDown(policy.dispose);
          var settings = 0;
          await tester.pumpWidget(
            _app(
              WalletRecoveryPanel(
                status: _paused(policy),
                onRetry: () =>
                    fail('network policy pause must not request a retry'),
                onSettings: () => settings++,
                onTorSettings: () =>
                    fail('network policy pause must not change Tor'),
                onContinueOnMobileData: policy.continueOnMobileData,
              ),
              dark: dark,
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(paused), findsOneWidget);
          expect(find.byType(BullFadingLinearProgress), findsNothing);
          final status = _paused(policy);
          expect(status.checkedBlocks, 1000);
          expect(status.totalBlocks, 2000);
          await tester.ensureVisible(find.text(consent));
          await tester.tap(find.text(consent));
          expect(policy.consents, 1);
          final settingsButton = find.byWidgetPredicate(
            (widget) => widget is BullButton && widget.label != consent,
          );
          expect(settingsButton, findsOneWidget);
          await tester.ensureVisible(settingsButton);
          await tester.tap(settingsButton);
          expect(settings, 1);
          await _close(tester);
        },
      );

      testWidgets(
        'paused warm wallet keeps network settings reachable despite old Tor failure $locale/$dark',
        (tester) async {
          final policy = _Policy(wifiOnly: true);
          addTearDown(policy.dispose);
          var settings = 0;
          await tester.pumpWidget(
            _app(
              WalletRecoveryPanel(
                status: _paused(policy).copyWith(
                  recoveryRequired: false,
                  emptyRecovery: true,
                  failure: const WalletSyncTorFailure(),
                ),
                onRetry: () => fail('network policy needs consent'),
                onSettings: () => settings++,
                onTorSettings: () =>
                    fail('network pause must expose sync settings'),
                onContinueOnMobileData: policy.continueOnMobileData,
              ),
              dark: dark,
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(paused), findsOneWidget);
          final settingsButton = find.byWidgetPredicate(
            (widget) => widget is BullButton && widget.label != consent,
          );
          await tester.ensureVisible(settingsButton);
          await tester.tap(settingsButton);
          expect(settings, 1);
          await _close(tester);
        },
      );

      testWidgets(
        'paused wallet card exposes one-tap mobile consent $locale/$dark',
        (tester) async {
          final policy = _Policy(wifiOnly: true);
          addTearDown(policy.dispose);
          var settings = 0;
          await tester.pumpWidget(
            _app(
              WalletIncompleteBalance(
                status: _paused(policy).copyWith(recoveryRequired: false),
                onContinueOnMobileData: policy.continueOnMobileData,
                onSettings: () => settings++,
              ),
              dark: dark,
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(paused), findsOneWidget);
          expect(find.byType(BullCircularProgress), findsNothing);
          await tester.tap(find.text(consent));
          expect(policy.consents, 1);
          final settingsButton = find.byWidgetPredicate(
            (widget) => widget is BullButton && widget.label != consent,
          );
          await tester.tap(settingsButton);
          expect(settings, 1);
          await _close(tester);
        },
      );
    }
  }
}
