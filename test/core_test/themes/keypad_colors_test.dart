import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The dark keypad was drawn from the app palette; until that palette moves into bull_ui, the two must not drift apart.
  test('the dark keypad matches the app dark palette', () {
    const keypad = BullKeypadColors.dark;
    const colors = AppColors.dark;
    expect(keypad.panel, colors.surfaceContainerHighest);
    expect(keypad.key, colors.background);
    expect(keypad.onKey, colors.onSurface);
    expect(keypad.functionKey, colors.outline);
    expect(keypad.onFunctionKeyDisabled, colors.textMuted);
    expect(keypad.disabledGlyph, colors.outline);
  });

  test('each app theme registers the keypad of its brightness', () {
    expect(
      AppTheme.themeData(AppThemeType.light).extension<BullKeypadColors>(),
      BullKeypadColors.light,
    );
    expect(
      AppTheme.themeData(AppThemeType.dark).extension<BullKeypadColors>(),
      BullKeypadColors.dark,
    );
  });
}
