import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Wallet extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

Future<void> _pump(WidgetTester tester, {required bool hideAmounts}) async {
  final wallet = _Wallet();
  whenListen(
    wallet,
    const Stream<WalletState>.empty(),
    initialState: WalletState(
      amountDisplay: (
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
        hideAmounts: hideAmounts,
      ),
    ),
  );
  await tester.pumpWidget(
    BlocProvider<WalletBloc>.value(
      value: wallet,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: EyeToggle())),
      ),
    ),
  );
}

void main() {
  testWidgets('names the action and offers a 48 dp target', (tester) async {
    await _pump(tester, hideAmounts: true);
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    final size = tester.getSize(find.byType(EyeToggle));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await _pump(tester, hideAmounts: false);
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
  });
}
