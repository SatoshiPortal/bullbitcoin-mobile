import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overview/overview.dart';

void main() {
  testWidgets(
    'Silent balance keeps the supplied slots and noninteractive sats',
    (tester) async {
      final background = AssetImage(Assets.backgrounds.bgSecureWallet.path);
      const eye = Text('visibility control');
      const fiat = Text('fiat quote');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: bullUiLocalizationsDelegates,
          home: Scaffold(
            body: SilentWalletBalance(
              background: background,
              balanceSat: 1200,
              eyeToggle: eye,
              fiatBalance: fiat,
            ),
          ),
        ),
      );
      final card = tester.widget<WalletDetailBalanceCard>(
        find.byType(WalletDetailBalanceCard),
      );
      expect(card.background, same(background));
      expect(card.eyeToggle, same(eye));
      expect(card.fiatBalance, same(fiat));
      final amount = tester.widget<BullAmount>(find.byType(BullAmount));
      expect(amount.magnitude.value, BigInt.from(1200));
      expect(amount.interactive, isFalse);
    },
  );
}
