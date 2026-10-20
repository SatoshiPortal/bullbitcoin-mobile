import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_cubes_loader.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';

void main() {
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final reducedMotion in [false, true]) {
      testWidgets('acceleration tile $theme reduced motion $reducedMotion', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(theme),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: Scaffold(
                body: AccelerateTransactionListTile(
                  orderId: 'order',
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.getSize(find.byType(BuyCubesLoader)), const Size(36, 36));
        expect(find.byType(Gif), reducedMotion ? findsNothing : findsOneWidget);
        expect(
          find.byIcon(Icons.schedule),
          reducedMotion ? findsOneWidget : findsNothing,
        );
        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect((tile.title as Text).data, isNotEmpty);
        expect((tile.subtitle as Text).data, isNotEmpty);
        expect(find.byIcon(Icons.fast_forward_outlined), findsOneWidget);
        await tester.tap(find.byType(ListTile));
        expect(taps, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
