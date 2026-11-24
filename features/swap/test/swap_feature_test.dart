import 'dart:ui' show Tristate;

import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:swap_feature/src/swap_feature.dart' show swapSettingsRoute;
import 'package:swap_feature/src/presentation/swap_settings_failure_l10n.dart';
import 'package:swaps/swaps.dart';

class _MockSwapRouting extends Mock implements SwapRouting {}

class _MockSwapServerSettings extends Mock implements SwapServerSettings {}

void main() {
  test('resolves existing locale variants and falls back to English', () {
    expect(SwapNavigation.settingsTitle('es_MX'), 'Intercambios');
    expect(SwapNavigation.settingsTitle('xx'), 'Swaps');
  });

  testWidgets('keeps the specific server error labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(const SwapsBusyFailure().toTranslated(context)),
              Text(
                const SwapsUnsupportedNetworkFailure().toTranslated(context),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.text('Finish your ongoing swaps before changing the swap server.'),
      findsOneWidget,
    );
    expect(
      find.text('This feature is unavailable on the selected network.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'opens the existing settings route and toggles the named switch',
    (tester) async {
      final routing = _MockSwapRouting();
      final servers = _MockSwapServerSettings();
      when(servers.readServer).thenAnswer(
        (_) async => const Ok((
          server: SwapServer.mainnetDefault,
          environment: NetworkEnv.mainnet,
        )),
      );
      when(routing.readRouteSettings).thenAnswer(
        (_) async => const Ok((
          exchangeFallbackEnabled: false,
          override: SwapRouteOverride.auto,
          devModeEnabled: false,
        )),
      );
      when(() => routing.setExchangeFallbackEnabled(true))
          .thenAnswer((_) async => const Ok(null));

      final settings = swapSettingsRoute(routing, servers);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => SwapNavigation.openSettings(context),
                child: const Text('Open settings'),
              ),
            ),
          ),
          settings,
        ],
      );
      addTearDown(router.dispose);
      final semantics = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          MaterialApp.router(
            theme: ThemeData(extensions: testBullExtensions),
            routerConfig: router,
          ),
        );
        verifyZeroInteractions(routing);
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        expect(router.namedLocation('swapSettings'), '/swap-settings');
        expect(find.text('Swaps'), findsOneWidget);
        final toggle = find.bySemanticsLabel(
          'Fall back to the Bull Bitcoin exchange',
        );
        expect(toggle, findsOneWidget);
        expect(
          tester.getSemantics(toggle).flagsCollection.isToggled,
          Tristate.isFalse,
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(toggle).flagsCollection.isToggled,
          Tristate.isTrue,
        );
        verify(() => routing.setExchangeFallbackEnabled(true)).called(1);
      } finally {
        semantics.dispose();
      }
    },
  );
}
