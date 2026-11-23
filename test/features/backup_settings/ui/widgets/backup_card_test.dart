import 'package:bull_ui/app_theme.dart';
import 'package:backups/backups.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final (type, colors) in [
    (AppThemeType.light, AppColors.light),
    (AppThemeType.dark, AppColors.dark),
  ]) {
    testWidgets('paints the banner roles with 16 around the content ($type)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(type),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BackupCard(
              icon: AssetImage(Assets.misc.passwordbook.path),
              onTap: () => taps++,
            ),
          ),
        ),
      );
      final banner = find.byType(BackupCard);
      final card = find.descendant(
        of: banner,
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(card.first).decoration as BoxDecoration?;
      expect(decoration?.color, colors.banner);
      expect(decoration?.border, isNull);
      expect(decoration?.boxShadow?.single.color, colors.scrim);
      final icon = find.byType(Image);
      expect(tester.widget<Image>(icon).color, colors.onBanner);
      expect(
        tester.getTopLeft(icon) - tester.getTopLeft(card.first),
        const Offset(16, 16),
      );
      expect(tester.getSize(banner).shortestSide, greaterThanOrEqualTo(48));

      final loc = AppLocalizations.of(tester.element(banner));
      final semantics = tester.ensureSemantics();
      try {
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(loc.backupCardTitle))),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
      await tester.tap(banner);
      expect(taps, 1);
    });
  }
}
