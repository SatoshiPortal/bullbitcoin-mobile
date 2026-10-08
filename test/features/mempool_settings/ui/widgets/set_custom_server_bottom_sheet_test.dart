import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/set_custom_server_bottom_sheet.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'lays out TLS controls on a compact screen with the keyboard open',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 480),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: Scaffold(
              body: SetCustomServerBottomSheet(
                initialUrl: 'mempool.local',
                initialEnableSsl: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Validate Domain'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        tester.getTopLeft(find.textContaining('For local')).dy,
        lessThan(tester.getTopLeft(find.text('Validate Domain')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
