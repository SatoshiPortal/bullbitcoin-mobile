import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/features/address_view/ui/screens/addresses_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class _AddressView extends MockBloc<AddressViewEvent, AddressViewState>
    implements AddressViewBloc {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('Liquid change address notice in ${theme.name}', (
      tester,
    ) async {
      final bloc = _AddressView();
      whenListen(
        bloc,
        const Stream<AddressViewState>.empty(),
        initialState: const AddressViewState(isLiquid: true),
      );
      final loc = await _pump(
        tester,
        theme,
        BlocProvider<AddressViewBloc>.value(
          value: bloc,
          child: const AddressesScreen(walletId: 'example'),
        ),
      );
      await tester.tap(find.text(loc.addressViewChangeType));
      await tester.pumpAndSettle();
      final sheet = find.byType(BullBottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.text(loc.addressViewChangeAddressesDescription),
        findsOneWidget,
      );

      await tester.tap(find.text(loc.okButton));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(
        find.text(loc.addressViewChangeAddressesComingSoon),
        findsOneWidget,
      );
    });
  }
}

Future<AppLocalizations> _pump(
  WidgetTester tester,
  AppThemeType theme,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
  );
  addTearDown(router.dispose);
  final app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.themeData(theme),
    localizationsDelegates: const [
      bullUiLocalizationsDelegate,
      ...appLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(Scaffold)));
}
