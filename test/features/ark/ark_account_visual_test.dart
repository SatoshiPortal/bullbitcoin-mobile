import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmountScope, BullAmountSnapshot;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'package:ark/ark.dart';

import '../../../features/ark/test/ark_account_screen_test.dart' as wallet;
import '../../../features/ark/test/ark_operations_test.dart' show account;

void main() {
  setUpAll(() async {
    for (final entry in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Golos Text': 'assets/fonts/GolosText.ttf',
      'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  for (final theme in AppThemeType.values) {
    for (final empty in [false, true]) {
      testWidgets(
        'Ark account ${empty ? 'empty' : 'funded'} visual ${theme.name}',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final snapshot = empty
              ? ArkSnapshot(
                  account: account(),
                  revision: 2,
                  observedAt: DateTime.utc(2026, 11, 16),
                  stale: false,
                  spendable: Sats.zero,
                  pending: Sats.zero,
                  confirmedReserve: Sats.zero,
                  recovery: ArkRecoveryStatus.complete,
                  renewal: ArkRenewalStatus.current,
                )
              : wallet.observation();
          final cubit = wallet.controller(
            wallet.Client()..snapshot = Ok(snapshot),
          );
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              theme: AppTheme.themeData(theme),
              supportedLocales: ArkLocalizations.supportedLocales,
              localizationsDelegates: const [
                ArkLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: RepaintBoundary(
                key: boundary,
                child: BullAmountScope(
                  snapshot: const BullAmountSnapshot(
                    unit: BitcoinUnit.sats,
                    hideAmounts: false,
                    isReady: true,
                  ),
                  writeUnit: (_) async => false,
                  child: wallet.screen(cubit, []),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile(
              'goldens/${empty ? 'SendArkWalletEmpty' : 'SendArkWallet'}-${theme.name}.png',
            ),
          );
        },
      );
    }
  }
}
