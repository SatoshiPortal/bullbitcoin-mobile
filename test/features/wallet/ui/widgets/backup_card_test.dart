import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/backup_card.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullSizes;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final (type, colors) in [
    (AppThemeType.light, AppColors.light),
    (AppThemeType.dark, AppColors.dark),
  ]) {
    testWidgets('paints the banner roles at the home card height ($type)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(type),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BackupCard(onTap: () {})),
        ),
      );
      final card = find.descendant(
        of: find.byType(BackupCard),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(card.first).decoration as BoxDecoration?;
      expect(decoration?.color, colors.banner);
      expect(decoration?.border, isNull);
      expect(decoration?.boxShadow?.single.color, colors.scrim);
      final icon = find.byType(Image);
      expect(tester.widget<Image>(icon).color, colors.onBanner);
      final cardRect = tester.getRect(card.first);
      final iconRect = tester.getRect(icon);
      expect(cardRect.height, greaterThanOrEqualTo(BullSizes.homeCard));
      expect(iconRect.left - cardRect.left, 16);
      expect(iconRect.center.dy, cardRect.center.dy);
    });
  }
}
