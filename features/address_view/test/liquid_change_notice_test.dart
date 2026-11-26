import 'package:address_view/src/presentation/address_view_bloc.dart';
import 'package:address_view/src/ui/addresses_screen.dart';
import 'package:address_view/routes.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _AddressView extends Mock implements AddressViewBloc {}

void main() {
  for (final theme in Brightness.values) {
    testWidgets('Liquid change address notice in ${theme.name}', (
      tester,
    ) async {
      final bloc = _AddressView();
      when(() => bloc.stream)
          .thenAnswer((_) => const Stream<AddressViewState>.empty());
      when(() => bloc.state).thenReturn(const AddressViewState(isLiquid: true));
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

Future<AddressViewLocalizations> _pump(
  WidgetTester tester,
  Brightness theme,
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
    theme: ThemeData(
      brightness: theme,
      extensions: bullUiExtensions(
        colors: testBullTheme,
        brightness: theme,
        typography: testBullTypography,
      ),
    ),
    localizationsDelegates: const [
      bullUiLocalizationsDelegate,
      ...AddressViewLocalizations.localizationsDelegates,
    ],
    supportedLocales: AddressViewLocalizations.supportedLocales,
    routerConfig: router,
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  return AddressViewLocalizations.of(tester.element(find.byType(Scaffold)));
}
