import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/swaps.dart'
    show
        SwapServer,
        SwapServerCredentials,
        SwapsBoltzRejectedFailure,
        SwapsBoltzUnavailableFailure,
        SwapsFailure;
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile;
import 'package:bull_ui/testing.dart' show testBullExtensions;

import 'dart:async';

import 'package:swap_feature/src/presentation/swap_settings_cubit.dart';
import 'package:swap_feature/src/ui/swap_settings_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapSettingsCubit extends Mock implements SwapSettingsCubit {}

void main() {
  late _MockSwapSettingsCubit cubit;

  Future<void> pump(WidgetTester tester, SwapSettingsState state) async {
    cubit = _MockSwapSettingsCubit();
    when(() => cubit.state).thenReturn(state);
    when(
      () => cubit.stream,
    ).thenAnswer((_) => StreamController<SwapSettingsState>.broadcast().stream);
    when(() => cubit.close()).thenAnswer((_) async {});
    when(() => cubit.setExchangeFallbackEnabled(any()))
        .thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        home: BlocProvider<SwapSettingsCubit>.value(
          value: cubit,
          child: const SwapSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final environment in [null, ...NetworkEnv.values]) {
    testWidgets(
      'custom swap editor admits only known historical network $environment',
      (tester) async {
        await pump(
          tester,
          SwapSettingsState(loaded: true, swapServerEnvironment: environment),
        );
        expect(
          find.byType(BullBorderedTile),
          environment == NetworkEnv.mainnet || environment == NetworkEnv.testnet
              ? findsOneWidget
              : findsNothing,
        );
      },
    );
  }

  testWidgets('stored credentials do not follow an edited server address', (
    tester,
  ) async {
    await pump(
      tester,
      SwapSettingsState(
        loaded: true,
        swapServerEnvironment: NetworkEnv.mainnet,
        swapServer: SwapServer.mainnetDefault.withCredentials(
          const SwapServerCredentials(username: 'bull', password: 'secret'),
        ),
      ),
    );
    when(
      () => cubit.setSwapServer(
        any(),
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => null);
    await tester.tap(find.byType(BullBorderedTile));
    await tester.pumpAndSettle();
    expect(find.text('bull'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'other.example.com');
    await tester.pump();

    expect(find.text('bull'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verify(
      () =>
          cubit.setSwapServer('other.example.com', username: '', password: ''),
    ).called(1);
  });

  for (final (failure, title, detail) in <(SwapsFailure?, String, String)>[
    (
      null,
      'Connected',
      'The swap server accepted the request. Swaps can use it.',
    ),
    (
      const SwapsBoltzRejectedFailure('401'),
      'Refused by the server',
      'The swap server rejected the request. Check the username and password.',
    ),
    (
      const SwapsBoltzUnavailableFailure('offline'),
      'No answer',
      'The swap server could not be reached. Check the address and your '
          'connection.',
    ),
  ]) {
    testWidgets('the connection test stays on the page as "$title"', (
      tester,
    ) async {
      await pump(
        tester,
        const SwapSettingsState(
          loaded: true,
          swapServerEnvironment: NetworkEnv.mainnet,
        ),
      );
      final answer = Completer<SwapsFailure?>();
      when(() => cubit.checkSwapServer()).thenAnswer((_) => answer.future);

      await tester.tap(find.text('Test connection'));
      await tester.pump();

      expect(find.text('Testing…'), findsOneWidget);
      expect(find.text(SwapServer.mainnetDefault.host), findsOneWidget);

      answer.complete(failure);
      await tester.pumpAndSettle();

      verify(() => cubit.checkSwapServer()).called(1);
      expect(find.text(title), findsOneWidget);
      expect(find.text(detail), findsOneWidget);
      expect(find.text(SwapServer.mainnetDefault.host), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
    });
  }

  testWidgets('the provider override is offered only in dev mode', (
    tester,
  ) async {
    await pump(tester, const SwapSettingsState(loaded: true));
    expect(find.text('Swap provider'), findsNothing);

    await pump(
      tester,
      const SwapSettingsState(loaded: true, devModeEnabled: true),
    );
    expect(find.text('Swap provider'), findsOneWidget);
    expect(find.text('Boltz only'), findsOneWidget);
  });

  testWidgets('the fallback switch turns the fallback on', (tester) async {
    await pump(tester, const SwapSettingsState(loaded: true));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    verify(() => cubit.setExchangeFallbackEnabled(true)).called(1);
  });

  testWidgets('the switch is inert until the stored value is known', (
    tester,
  ) async {
    await pump(tester, const SwapSettingsState());

    await tester.tap(find.byType(Switch));
    await tester.pump();

    verifyNever(() => cubit.setExchangeFallbackEnabled(any()));
  });
}
