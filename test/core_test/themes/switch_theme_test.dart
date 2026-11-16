import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/colors.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (type, colors) in [
    (AppThemeType.light, AppColors.light),
    (AppThemeType.dark, AppColors.dark),
  ]) {
    testWidgets('every Material switch shows its state ($type)', (
      tester,
    ) async {
      final theme = AppTheme.themeData(type).switchTheme;
      const on = {WidgetState.selected};
      const off = <WidgetState>{};
      expect(theme.thumbIcon?.resolve(off)?.icon, Icons.close);
      expect(theme.trackOutlineColor?.resolve(off), colors.outline);
      expect(theme.thumbIcon?.resolve(on)?.icon, Icons.check);
      expect(theme.trackColor?.resolve(on), colors.primary);

      // A raw Switch picks the look up from the app theme.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(type),
          home: Scaffold(body: Switch(value: false, onChanged: (_) {})),
        ),
      );
      expect(
        SwitchTheme.of(tester.element(find.byType(Switch))).thumbIcon
            ?.resolve(off)
            ?.icon,
        Icons.close,
      );
    });
  }
}
