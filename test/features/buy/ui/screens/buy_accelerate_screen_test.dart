import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_accelerate_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBuyOrder extends Mock implements BuyOrder {}

/// A loaded order, stubbed only with what the screen reads off it.
BuyOrder _loadedOrder() {
  final order = _MockBuyOrder();
  when(() => order.payinCurrency).thenReturn('CAD');
  return order;
}

Future<BuyBloc> _pumpAccelerateScreen(
  WidgetTester tester,
  BuyState state,
) async {
  final buyBloc = _MockBuyBloc();
  final settingsCubit = _MockSettingsCubit();

  when(() => buyBloc.state).thenReturn(state);
  when(() => buyBloc.stream).thenAnswer((_) => const Stream<BuyState>.empty());
  when(() => settingsCubit.state).thenReturn(
    const SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    ),
  );
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BuyBloc>.value(value: buyBloc),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: const BuyAccelerateScreen(),
      ),
    ),
  );
  // Not pumpAndSettle: while the fee reads are in flight the rows shimmer,
  // and a repeating animation never settles.
  await tester.pump();

  return buyBloc;
}

void main() {
  const genericMessage =
      'Your order could not be created right now. '
      'Please try again or contact support.';

  testWidgets('shows a failure raised before the order finished loading', (
    tester,
  ) async {
    // The route builds its own bloc, so the entry refresh fails with buyOrder
    // still null. That used to render nothing at all.
    await _pumpAccelerateScreen(
      tester,
      const BuyState(failure: BuyUnexpectedFailure('DioException 500')),
    );

    expect(find.text(genericMessage), findsOneWidget);
  });

  testWidgets('never shows the raw reason it carries', (tester) async {
    await _pumpAccelerateScreen(
      tester,
      const BuyState(failure: BuyUnexpectedFailure('DioException 500')),
    );

    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('shows nothing when nothing failed', (tester) async {
    await _pumpAccelerateScreen(tester, const BuyState());

    expect(find.text(genericMessage), findsNothing);
  });

  testWidgets('stops the fee rows shimmering once the reads have failed', (
    tester,
  ) async {
    // Otherwise the rows keep asking the user to wait for a value that is
    // never coming, directly above a message saying it failed.
    await _pumpAccelerateScreen(
      tester,
      const BuyState(failure: BuyUnexpectedFailure('DioException 500')),
    );

    expect(find.byType(LoadingLineContent), findsNothing);
    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('still shimmers while the fee reads are in flight', (
    tester,
  ) async {
    await _pumpAccelerateScreen(tester, const BuyState());

    expect(find.byType(LoadingLineContent), findsNWidgets(3));
    expect(find.text('—'), findsNothing);
  });

  group('the express confirm button', () {
    const confirmExpress = 'Confirm express';

    testWidgets('does nothing while there is no order to accelerate', (
      tester,
    ) async {
      // The handler bails out on a null order id with a severe log, so an
      // enabled button here is a tap that looks accepted and does nothing.
      final buyBloc = await _pumpAccelerateScreen(
        tester,
        const BuyState(failure: BuyUnexpectedFailure('DioException 500')),
      );

      await tester.tap(find.text(confirmExpress));
      await tester.pump();

      verifyNever(
        () => buyBloc.add(const BuyEvent.accelerateTransactionConfirmed()),
      );
    });

    testWidgets('stays usable after a failure that left the order loaded', (
      tester,
    ) async {
      // A failed confirm attempt is a legitimate retry, so the gate is the
      // missing order rather than the failure.
      final buyBloc = await _pumpAccelerateScreen(
        tester,
        BuyState(
          buyOrder: _loadedOrder(),
          failure: const BuyUnexpectedFailure('DioException 500'),
        ),
      );

      await tester.tap(find.text(confirmExpress));
      await tester.pump();

      verify(
        () => buyBloc.add(const BuyEvent.accelerateTransactionConfirmed()),
      ).called(1);
    });
  });
}
